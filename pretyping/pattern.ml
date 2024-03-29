(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2010     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

open Errors
open Util
open Names
open Libnames
open Nameops
open Term
open Glob_term
open Environ
open Nametab
open Pp
open Mod_subst

(* Metavariables *)

type constr_under_binders = identifier list * constr

type patvar_map = (patvar * constr) list
type extended_patvar_map = (patvar * constr_under_binders) list

(* Patterns *)

type case_info_pattern =
    { cip_style : case_style;
      cip_ind : inductive option;
      cip_ind_args : int option; (** number of args *)
      cip_extensible : bool (** does this match end with _ => _ ? *) }

type constr_pattern =
  | PRef of global_reference
  | PVar of identifier
  | PEvar of existential_key * constr_pattern array
  | PRel of int
  | PApp of constr_pattern * constr_pattern array
  | PSoApp of patvar * constr_pattern list
  | PLambda of name * constr_pattern * constr_pattern
  | PProd of name * constr_pattern * constr_pattern
  | PLetIn of name * constr_pattern * constr_pattern
  | PSort of glob_sort
  | PMeta of patvar option
  | PIf of constr_pattern * constr_pattern * constr_pattern
  | PCase of case_info_pattern * constr_pattern * constr_pattern *
      (int * int * constr_pattern) list (** constructor index, nb of args *)
  | PFix of fixpoint
  | PCoFix of cofixpoint

let rec occur_meta_pattern = function
  | PApp (f,args) ->
      (occur_meta_pattern f) or (array_exists occur_meta_pattern args)
  | PLambda (na,t,c)  -> (occur_meta_pattern t) or (occur_meta_pattern c)
  | PProd (na,t,c)  -> (occur_meta_pattern t) or (occur_meta_pattern c)
  | PLetIn (na,t,c)  -> (occur_meta_pattern t) or (occur_meta_pattern c)
  | PIf (c,c1,c2)  ->
      (occur_meta_pattern c) or
      (occur_meta_pattern c1) or (occur_meta_pattern c2)
  | PCase(_,p,c,br) ->
      (occur_meta_pattern p) or
      (occur_meta_pattern c) or
      (List.exists (fun (_,_,p) -> occur_meta_pattern p) br)
  | PMeta _ | PSoApp _ -> true
  | PEvar _ | PVar _ | PRef _ | PRel _ | PSort _ | PFix _ | PCoFix _ -> false

exception BoundPattern;;

let rec head_pattern_bound t =
  match t with
    | PProd (_,_,b)  -> head_pattern_bound b
    | PLetIn (_,_,b) -> head_pattern_bound b
    | PApp (c,args)  -> head_pattern_bound c
    | PIf (c,_,_)  -> head_pattern_bound c
    | PCase (_,p,c,br) -> head_pattern_bound c
    | PRef r         -> r
    | PVar id        -> VarRef id
    | PEvar _ | PRel _ | PMeta _ | PSoApp _  | PSort _ | PFix _
	-> raise BoundPattern
    (* Perhaps they were arguments, but we don't beta-reduce *)
    | PLambda _ -> raise BoundPattern
    | PCoFix _ -> anomaly "head_pattern_bound: not a type"

let head_of_constr_reference c = match kind_of_term c with
  | Const sp -> ConstRef sp
  | Construct sp -> ConstructRef sp
  | Ind sp -> IndRef sp
  | Var id -> VarRef id
  | _ -> anomaly "Not a rigid reference"

open Evd

let pattern_of_constr sigma t =
  let ctx = ref [] in
  let rec pattern_of_constr t =
  match kind_of_term t with
    | Rel n  -> PRel n
    | Meta n -> PMeta (Some (id_of_string ("META" ^ string_of_int n)))
    | Var id -> PVar id
    | Sort (Prop c) -> PSort (GProp c)
    | Sort (Type _) -> PSort (GType None)
    | Cast (c,_,_)      -> pattern_of_constr c
    | LetIn (na,c,_,b) -> PLetIn (na,pattern_of_constr c,pattern_of_constr b)
    | Prod (na,c,b)   -> PProd (na,pattern_of_constr c,pattern_of_constr b)
    | Lambda (na,c,b) -> PLambda (na,pattern_of_constr c,pattern_of_constr b)
    | App (f,a) ->
        (match 
          match kind_of_term f with
            Evar (evk,args as ev) ->
              (match snd (Evd.evar_source evk sigma) with
                  MatchingVar (true,id) ->
                    ctx := (id,None,existential_type sigma ev)::!ctx;
                    Some id
                | _ -> None)
            | _ -> None
          with
            | Some n -> PSoApp (n,Array.to_list (Array.map pattern_of_constr a))
            | None -> PApp (pattern_of_constr f,Array.map (pattern_of_constr) a))
    | Const sp         -> PRef (ConstRef (constant_of_kn(canonical_con sp)))
    | Ind sp        -> PRef (canonical_gr (IndRef sp))
    | Construct sp -> PRef (canonical_gr (ConstructRef sp))
    | Evar (evk,ctxt as ev) ->
        (match snd (Evd.evar_source evk sigma) with
          | MatchingVar (b,id) ->
              ctx := (id,None,existential_type sigma ev)::!ctx;
              assert (not b); PMeta (Some id)
          | GoalEvar -> PEvar (evk,Array.map pattern_of_constr ctxt)
          | _ -> PMeta None)
    | Case (ci,p,a,br) ->
        let cip =
	  { cip_style = ci.ci_pp_info.style;
	    cip_ind = Some ci.ci_ind;
	    cip_ind_args = Some (ci.ci_pp_info.ind_nargs);
	    cip_extensible = false }
	in
	let branch_of_constr i c =
	  (i, ci.ci_cstr_ndecls.(i), pattern_of_constr c)
	in
	PCase (cip, pattern_of_constr p, pattern_of_constr a,
	       Array.to_list (Array.mapi branch_of_constr br))
    | Fix f -> PFix f
    | CoFix f -> PCoFix f in
  let p = pattern_of_constr t in
  (* side-effect *)
  (* Warning: the order of dependencies in ctx is not ensured *)
  (!ctx,p)

(* To process patterns, we need a translation without typing at all. *)

let map_pattern_with_binders g f l = function
  | PApp (p,pl) -> PApp (f l p, Array.map (f l) pl)
  | PSoApp (n,pl) -> PSoApp (n, List.map (f l) pl)
  | PLambda (n,a,b) -> PLambda (n,f l a,f (g n l) b)
  | PProd (n,a,b) -> PProd (n,f l a,f (g n l) b)
  | PLetIn (n,a,b) -> PLetIn (n,f l a,f (g n l) b)
  | PIf (c,b1,b2) -> PIf (f l c,f l b1,f l b2)
  | PCase (ci,po,p,pl) ->
    PCase (ci,f l po,f l p, List.map (fun (i,n,c) -> (i,n,f l c)) pl)
  (* Non recursive *)
  | (PVar _ | PEvar _ | PRel _ | PRef _  | PSort _  | PMeta _
  (* Bound to terms *)
  | PFix _ | PCoFix _ as x) -> x

let error_instantiate_pattern id l =
  let is = if List.length l = 1 then "is" else "are" in
  errorlabstrm "" (str "Cannot substitute the term bound to " ++ pr_id id
    ++ strbrk " in pattern because the term refers to " ++ pr_enum pr_id l
    ++ strbrk " which " ++ str is ++ strbrk " not bound in the pattern.")

let instantiate_pattern sigma lvar c =
  let rec aux vars = function
  | PVar id as x ->
      (try
	let ctx,c = List.assoc id lvar in
	try
	  let inst =
	    List.map (fun id -> mkRel (list_index (Name id) vars)) ctx in
	  let c = substl inst c in
	  snd (pattern_of_constr sigma c)
	with Not_found (* list_index failed *) ->
	  let vars =
	    list_map_filter (function Name id -> Some id | _ -> None) vars in
	  error_instantiate_pattern id (list_subtract ctx vars)
       with Not_found (* List.assoc failed *) ->
	 x)
  | (PFix _ | PCoFix _) -> error ("Non instantiable pattern.")
  | c ->
      map_pattern_with_binders (fun id vars -> id::vars) aux vars c in
  aux [] c

let rec liftn_pattern k n = function
  | PRel i as x -> if i >= n then PRel (i+k) else x
  | PFix x -> PFix (destFix (liftn k n (mkFix x)))
  | PCoFix x -> PCoFix (destCoFix (liftn k n (mkCoFix x)))
  | c -> map_pattern_with_binders (fun _ -> succ) (liftn_pattern k) n c

let lift_pattern k = liftn_pattern k 1

let rec subst_pattern subst pat =
  match pat with
  | PRef ref ->
      let ref',t = subst_global subst ref in
	if ref' == ref then pat else
	 snd (pattern_of_constr Evd.empty t)
  | PVar _
  | PEvar _
  | PRel _ -> pat
  | PApp (f,args) ->
      let f' = subst_pattern subst f in
      let args' = array_smartmap (subst_pattern subst) args in
	if f' == f && args' == args then pat else
	  PApp (f',args')
  | PSoApp (i,args) ->
      let args' = list_smartmap (subst_pattern subst) args in
	if args' == args then pat else
	  PSoApp (i,args')
  | PLambda (name,c1,c2) ->
      let c1' = subst_pattern subst c1 in
      let c2' = subst_pattern subst c2 in
	if c1' == c1 && c2' == c2 then pat else
	  PLambda (name,c1',c2')
  | PProd (name,c1,c2) ->
      let c1' = subst_pattern subst c1 in
      let c2' = subst_pattern subst c2 in
	if c1' == c1 && c2' == c2 then pat else
	  PProd (name,c1',c2')
  | PLetIn (name,c1,c2) ->
      let c1' = subst_pattern subst c1 in
      let c2' = subst_pattern subst c2 in
	if c1' == c1 && c2' == c2 then pat else
	  PLetIn (name,c1',c2')
  | PSort _
  | PMeta _ -> pat
  | PIf (c,c1,c2) ->
      let c' = subst_pattern subst c in
      let c1' = subst_pattern subst c1 in
      let c2' = subst_pattern subst c2 in
	if c' == c && c1' == c1 && c2' == c2 then pat else
	  PIf (c',c1',c2')
  | PCase (cip,typ,c,branches) ->
      let ind = cip.cip_ind in
      let ind' = Option.smartmap (Inductiveops.subst_inductive subst) ind in
      let cip' = if ind' == ind then cip else { cip with cip_ind = ind' } in
      let typ' = subst_pattern subst typ in
      let c' = subst_pattern subst c in
      let subst_branch ((i,n,c) as br) =
	let c' = subst_pattern subst c in
	if c' == c then br else (i,n,c')
      in
      let branches' = list_smartmap subst_branch branches in
      if cip' == cip && typ' == typ && c' == c && branches' == branches
      then pat
      else PCase(cip', typ', c', branches')
  | PFix fixpoint ->
      let cstr = mkFix fixpoint in
      let fixpoint' = destFix (subst_mps subst cstr) in
	if fixpoint' == fixpoint then pat else
	  PFix fixpoint'
  | PCoFix cofixpoint ->
      let cstr = mkCoFix cofixpoint in
      let cofixpoint' = destCoFix (subst_mps subst cstr) in
	if cofixpoint' == cofixpoint then pat else
	  PCoFix cofixpoint'

let mkPLambda na b = PLambda(na,PMeta None,b)
let rev_it_mkPLambda = List.fold_right mkPLambda

let err loc pp = user_err_loc (loc,"pattern_of_glob_constr", pp)

let rec pat_of_raw metas vars = function
  | GVar (_,id) ->
      (try PRel (list_index (Name id) vars)
       with Not_found -> PVar id)
  | GPatVar (_,(false,n)) ->
      metas := n::!metas; PMeta (Some n)
  | GRef (_,gr) ->
      PRef (canonical_gr gr)
  (* Hack pour ne pas réécrire une interprétation complète des patterns*)
  | GApp (_, GPatVar (_,(true,n)), cl) ->
      metas := n::!metas; PSoApp (n, List.map (pat_of_raw metas vars) cl)
  | GApp (_,c,cl) ->
      PApp (pat_of_raw metas vars c,
	    Array.of_list (List.map (pat_of_raw metas vars) cl))
  | GLambda (_,na,bk,c1,c2) ->
      name_iter (fun n -> metas := n::!metas) na;
      PLambda (na, pat_of_raw metas vars c1,
	       pat_of_raw metas (na::vars) c2)
  | GProd (_,na,bk,c1,c2) ->
      name_iter (fun n -> metas := n::!metas) na;
      PProd (na, pat_of_raw metas vars c1,
	       pat_of_raw metas (na::vars) c2)
  | GLetIn (_,na,c1,c2) ->
      name_iter (fun n -> metas := n::!metas) na;
      PLetIn (na, pat_of_raw metas vars c1,
	       pat_of_raw metas (na::vars) c2)
  | GSort (_,s) ->
      PSort s
  | GHole _ ->
      PMeta None
  | GCast (_,c,_) ->
      Flags.if_warn
        Pp.msg_warning (str "Cast not taken into account in constr pattern");
      pat_of_raw metas vars c
  | GIf (_,c,(_,None),b1,b2) ->
      PIf (pat_of_raw metas vars c,
           pat_of_raw metas vars b1,pat_of_raw metas vars b2)
  | GLetTuple (loc,nal,(_,None),b,c) ->
      let mkGLambda c na = GLambda (loc,na,Explicit,GHole (loc,Evd.InternalHole),c) in
      let c = List.fold_left mkGLambda c nal in
      let cip =
	{ cip_style = LetStyle;
	  cip_ind = None;
	  cip_ind_args = None;
	  cip_extensible = false }
      in
      PCase (cip, PMeta None, pat_of_raw metas vars b,
             [0,1,pat_of_raw metas vars c])
  | GCases (loc,sty,p,[c,(na,indnames)],brs) ->
      let get_ind = function
	| (_,_,[PatCstr(_,(ind,_),_,_)],_)::_ -> Some ind
	| _ -> None
      in
      let ind_nargs,ind = match indnames with
	| Some (_,ind,nal) -> Some (List.length nal), Some ind
	| None -> None, get_ind brs
      in
      let ext,brs = pats_of_glob_branches loc metas vars ind brs
      in
      let pred = match p,indnames with
	| Some p, Some (_,_,nal) ->
	  rev_it_mkPLambda nal (mkPLambda na (pat_of_raw metas vars p))
	| _ -> PMeta None
      in
      let info =
	{ cip_style = sty;
	  cip_ind = ind;
	  cip_ind_args = ind_nargs;
	  cip_extensible = ext }
      in
      (* Nota : when we have a non-trivial predicate,
	 the inductive type is known. Same when we have at least
	 one non-trivial branch. These facts are used in [Constrextern]. *)
      PCase (info, pred, pat_of_raw metas vars c, brs)

  | r -> err (loc_of_glob_constr r) (Pp.str "Non supported pattern.")

and pats_of_glob_branches loc metas vars ind brs =
  let get_arg = function
    | PatVar(_,na) -> na
    | PatCstr(loc,_,_,_) -> err loc (Pp.str "Non supported pattern.")
  in
  let rec get_pat indexes = function
    | [] -> false, []
    | [(_,_,[PatVar(_,Anonymous)],GHole _)] -> true, [] (* ends with _ => _ *)
    | (_,_,[PatCstr(_,(indsp,j),lv,_)],br) :: brs ->
      if ind <> None && ind <> Some indsp then
        err loc (Pp.str "All constructors must be in the same inductive type.");
      if Intset.mem (j-1) indexes then
	err loc
          (str "No unique branch for " ++ int j ++ str"-th constructor.");
      let lna = List.map get_arg lv in
      let vars' = List.rev lna @ vars in
      let pat = rev_it_mkPLambda lna (pat_of_raw metas vars' br) in
      let ext,pats = get_pat (Intset.add (j-1) indexes) brs in
      ext, ((j-1, List.length lv, pat) :: pats)
    | (loc,_,_,_) :: _ -> err loc (Pp.str "Non supported pattern.")
  in
  get_pat Intset.empty brs

let pattern_of_glob_constr c =
  let metas = ref [] in
  let p = pat_of_raw metas [] c in	
  (!metas,p)
