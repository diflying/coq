open Names
open Pp
open Libnames
open Refiner
open Hiddentac 
let mk_prefix pre id = id_of_string (pre^(string_of_id id))
let mk_rel_id = mk_prefix "R_"
let mk_correct_id id = Nameops.add_suffix (mk_rel_id id) "_correct"
let mk_complete_id id = Nameops.add_suffix (mk_rel_id id) "_complete"
let mk_equation_id id = Nameops.add_suffix id "_equation"

let msgnl m =
  ()

let invalid_argument s = raise (Invalid_argument s)


let fresh_id avoid s = Namegen.next_ident_away_in_goal (id_of_string s) avoid

let fresh_name avoid s = Name (fresh_id avoid s)

let get_name avoid ?(default="H") = function
  | Anonymous -> fresh_name avoid default
  | Name n -> Name n

let array_get_start a =
  try
    Array.init
      (Array.length a - 1)
      (fun i -> a.(i))
  with Invalid_argument "index out of bounds" ->
    invalid_argument "array_get_start"

let id_of_name = function
    Name id -> id
  | _ -> raise Not_found

let locate  ref =
    let (loc,qid) = qualid_of_reference ref in
    Nametab.locate qid

let locate_ind ref =
  match locate ref with
    | IndRef x -> x
    | _ -> raise Not_found

let locate_constant ref =
  match locate ref with
    | ConstRef x -> x
    | _ -> raise Not_found


let locate_with_msg msg f x =
  try
    f x
  with
    | Not_found -> raise (Errors.UserError("", msg))
    | e -> raise e


let filter_map filter f =
  let rec it = function
    | [] -> []
    | e::l ->
	if filter e
	then
	  (f e) :: it l
	else it l
  in
  it


let chop_rlambda_n  =
  let rec chop_lambda_n acc n rt =
      if n == 0
      then List.rev acc,rt
      else
	match rt with
	  | Glob_term.GLambda(_,name,k,t,b) -> chop_lambda_n ((name,t,false)::acc) (n-1) b
	  | Glob_term.GLetIn(_,name,v,b) -> chop_lambda_n ((name,v,true)::acc) (n-1) b
	  | _ ->
	      raise (Errors.UserError("chop_rlambda_n",
				    str "chop_rlambda_n: Not enough Lambdas"))
  in
  chop_lambda_n []

let chop_rprod_n  =
  let rec chop_prod_n acc n rt =
      if n == 0
      then List.rev acc,rt
      else
	match rt with
	  | Glob_term.GProd(_,name,k,t,b) -> chop_prod_n ((name,t)::acc) (n-1) b
	  | _ -> raise (Errors.UserError("chop_rprod_n",str "chop_rprod_n: Not enough products"))
  in
  chop_prod_n []



let list_union_eq eq_fun l1 l2 =
  let rec urec = function
    | [] -> l2
    | a::l -> if List.exists (eq_fun a) l2 then urec l else a::urec l
  in
  urec l1

let list_add_set_eq eq_fun x l =
  if List.exists (eq_fun x) l then l else x::l




let const_of_id id =
  let _,princ_ref =
    qualid_of_reference (Libnames.Ident (Pp.dummy_loc,id))
  in
  try Nametab.locate_constant princ_ref
  with Not_found -> Errors.error ("cannot find "^ string_of_id id)

let def_of_const t =
   match (Term.kind_of_term t) with
    Term.Const sp ->
      (try (match Declarations.body_of_constant (Global.lookup_constant sp) with
             | Some c -> Declarations.force c
	     | _ -> assert false)
       with _ -> assert false)
    |_ -> assert false

let coq_constant s =
  Coqlib.gen_constant_in_modules "RecursiveDefinition"
    Coqlib.init_modules s;;

let constant sl s =
  constr_of_global
    (Nametab.locate (make_qualid(Names.make_dirpath
			   (List.map id_of_string (List.rev sl)))
	       (id_of_string s)));;

let find_reference sl s =
    (Nametab.locate (make_qualid(Names.make_dirpath
			   (List.map id_of_string (List.rev sl)))
	       (id_of_string s)));;

let eq = lazy(coq_constant "eq")
let refl_equal = lazy(coq_constant "eq_refl")

(*****************************************************************)
(* Copy of the standart save mechanism but without the much too  *)
(* slow reduction function                                       *)
(*****************************************************************)
open Declarations
open Entries
open Decl_kinds
open Declare
let definition_message id =
  Flags.if_verbose message ((string_of_id id) ^ " is defined")


let save with_clean id const (locality,kind) hook =
  let {const_entry_body = pft;
       const_entry_secctx = _;
       const_entry_type = tpo;
       const_entry_opaque = opacity } = const in
  let l,r = match locality with
    | Local when Lib.sections_are_opened () ->
        let k = logical_kind_of_goal_kind kind in
	let c = SectionLocalDef (pft, tpo, opacity) in
	let _ = declare_variable id (Lib.cwd(), c, k) in
	(Local, VarRef id)
    | Local ->
        let k = logical_kind_of_goal_kind kind in
        let kn = declare_constant id (DefinitionEntry const, k) in
	(Global, ConstRef kn)
    | Global ->
        let k = logical_kind_of_goal_kind kind in
        let kn = declare_constant id (DefinitionEntry const, k) in
	(Global, ConstRef kn) in
  if with_clean then  Pfedit.delete_current_proof ();
  hook l r;
  definition_message id



let cook_proof _ =
  let (id,(entry,_,strength,hook)) = Pfedit.cook_proof (fun _ -> ()) in
  (id,(entry,strength,hook))

let new_save_named opacity =
  let id,(const,persistence,hook) = cook_proof true  in
  let const = { const with const_entry_opaque = opacity } in
  save true id const persistence hook

let get_proof_clean do_reduce =
  let result = cook_proof do_reduce in
  Pfedit.delete_current_proof ();
  result

let with_full_print f a =
  let old_implicit_args = Impargs.is_implicit_args ()
  and old_strict_implicit_args =  Impargs.is_strict_implicit_args ()
  and old_contextual_implicit_args = Impargs.is_contextual_implicit_args () in
  let old_rawprint = !Flags.raw_print in
  Flags.raw_print := true;
  Impargs.make_implicit_args false;
  Impargs.make_strict_implicit_args false;
  Impargs.make_contextual_implicit_args false;
  Impargs.make_contextual_implicit_args false;
  Dumpglob.pause ();
  try
    let res = f a in
    Impargs.make_implicit_args old_implicit_args;
    Impargs.make_strict_implicit_args old_strict_implicit_args;
    Impargs.make_contextual_implicit_args old_contextual_implicit_args;
    Flags.raw_print := old_rawprint;
    Dumpglob.continue ();
    res
  with
    | e ->
	Impargs.make_implicit_args old_implicit_args;
	Impargs.make_strict_implicit_args old_strict_implicit_args;
	Impargs.make_contextual_implicit_args old_contextual_implicit_args;
	Flags.raw_print := old_rawprint;
	Dumpglob.continue ();
	raise e






(**********************)

type function_info =
    {
      function_constant : constant;
      graph_ind : inductive;
      equation_lemma : constant option;
      correctness_lemma : constant option;
      completeness_lemma : constant option;
      rect_lemma : constant option;
      rec_lemma : constant option;
      prop_lemma : constant option;
      is_general : bool; (* Has this function been defined using general recursive definition *)
    }


(* type function_db  = function_info list *)

(* let function_table = ref ([] : function_db) *)


let from_function = ref Cmap.empty
let from_graph = ref Indmap.empty
(*
let rec do_cache_info finfo = function
  | [] -> raise Not_found
  | (finfo'::finfos as l) ->
      if finfo' == finfo then l
      else if finfo'.function_constant = finfo.function_constant
      then finfo::finfos
      else
	let res = do_cache_info finfo finfos in
	if res == finfos then l else  finfo'::l


let cache_Function (_,(finfos)) =
  let new_tbl =
    try do_cache_info finfos !function_table
    with Not_found -> finfos::!function_table
  in
  if new_tbl != !function_table
  then function_table := new_tbl
*)

let cache_Function (_,finfos) =
  from_function := Cmap.add finfos.function_constant finfos !from_function;
  from_graph := Indmap.add finfos.graph_ind finfos !from_graph


let load_Function _  = cache_Function
let open_Function _ = cache_Function
let subst_Function (subst,finfos) =
  let do_subst_con c = fst (Mod_subst.subst_con subst c)
  and do_subst_ind (kn,i) = (Mod_subst.subst_ind subst kn,i)
  in
  let function_constant' = do_subst_con finfos.function_constant in
  let graph_ind' = do_subst_ind finfos.graph_ind in
  let equation_lemma' = Option.smartmap do_subst_con finfos.equation_lemma in
  let correctness_lemma' = Option.smartmap do_subst_con finfos.correctness_lemma in
  let completeness_lemma' = Option.smartmap do_subst_con finfos.completeness_lemma in
  let rect_lemma' = Option.smartmap do_subst_con finfos.rect_lemma in
  let rec_lemma' = Option.smartmap do_subst_con finfos.rec_lemma in
  let prop_lemma' =  Option.smartmap do_subst_con finfos.prop_lemma in
  if function_constant' == finfos.function_constant &&
    graph_ind' == finfos.graph_ind &&
    equation_lemma' == finfos.equation_lemma &&
    correctness_lemma' == finfos.correctness_lemma &&
    completeness_lemma' == finfos.completeness_lemma &&
    rect_lemma' == finfos.rect_lemma &&
    rec_lemma' == finfos.rec_lemma &&
    prop_lemma' == finfos.prop_lemma
  then finfos
  else
    { function_constant = function_constant';
      graph_ind = graph_ind';
      equation_lemma = equation_lemma' ;
      correctness_lemma = correctness_lemma' ;
      completeness_lemma = completeness_lemma' ;
      rect_lemma = rect_lemma' ;
      rec_lemma = rec_lemma';
      prop_lemma = prop_lemma';
      is_general = finfos.is_general
    }

let classify_Function infos = Libobject.Substitute infos


let discharge_Function (_,finfos) =
  let function_constant' = Lib.discharge_con finfos.function_constant
  and graph_ind' = Lib.discharge_inductive finfos.graph_ind
  and equation_lemma' = Option.smartmap Lib.discharge_con finfos.equation_lemma
  and correctness_lemma' = Option.smartmap Lib.discharge_con finfos.correctness_lemma
  and completeness_lemma' = Option.smartmap Lib.discharge_con finfos.completeness_lemma
  and rect_lemma' = Option.smartmap Lib.discharge_con finfos.rect_lemma
  and rec_lemma' = Option.smartmap Lib.discharge_con finfos.rec_lemma
  and prop_lemma' = Option.smartmap Lib.discharge_con finfos.prop_lemma
  in
  if function_constant' == finfos.function_constant &&
    graph_ind' == finfos.graph_ind &&
    equation_lemma' == finfos.equation_lemma &&
    correctness_lemma' == finfos.correctness_lemma &&
    completeness_lemma' == finfos.completeness_lemma &&
    rect_lemma' == finfos.rect_lemma &&
    rec_lemma' == finfos.rec_lemma &&
    prop_lemma' == finfos.prop_lemma
  then Some finfos
  else
    Some { function_constant = function_constant' ;
	   graph_ind = graph_ind' ;
	   equation_lemma = equation_lemma' ;
	   correctness_lemma = correctness_lemma' ;
	   completeness_lemma = completeness_lemma';
	   rect_lemma = rect_lemma';
	   rec_lemma = rec_lemma';
	   prop_lemma = prop_lemma' ;
	   is_general = finfos.is_general
	 }

open Term
let pr_info f_info =
  str "function_constant := " ++ Printer.pr_lconstr (mkConst f_info.function_constant)++ fnl () ++
    str "function_constant_type := " ++
    (try Printer.pr_lconstr (Global.type_of_global (ConstRef f_info.function_constant)) with _ -> mt ()) ++ fnl () ++
    str "equation_lemma := " ++ (Option.fold_right (fun v acc -> Printer.pr_lconstr (mkConst v)) f_info.equation_lemma (mt ()) ) ++ fnl () ++
    str "completeness_lemma :=" ++ (Option.fold_right (fun v acc -> Printer.pr_lconstr (mkConst v)) f_info.completeness_lemma (mt ()) ) ++ fnl () ++
    str "correctness_lemma := " ++ (Option.fold_right (fun v acc -> Printer.pr_lconstr (mkConst v)) f_info.correctness_lemma (mt ()) ) ++ fnl () ++
    str "rect_lemma := " ++ (Option.fold_right (fun v acc -> Printer.pr_lconstr (mkConst v)) f_info.rect_lemma (mt ()) ) ++ fnl () ++
    str "rec_lemma := " ++ (Option.fold_right (fun v acc -> Printer.pr_lconstr (mkConst v)) f_info.rec_lemma (mt ()) ) ++ fnl () ++
    str "prop_lemma := " ++ (Option.fold_right (fun v acc -> Printer.pr_lconstr (mkConst v)) f_info.prop_lemma (mt ()) ) ++ fnl () ++
    str "graph_ind := " ++ Printer.pr_lconstr (mkInd f_info.graph_ind) ++ fnl ()

let pr_table tb =
  let l = Cmap.fold (fun k v acc -> v::acc) tb [] in
  Pp.prlist_with_sep fnl pr_info l

let in_Function : function_info -> Libobject.obj =
  Libobject.declare_object
    {(Libobject.default_object "FUNCTIONS_DB") with
       Libobject.cache_function = cache_Function;
       Libobject.load_function  = load_Function;
       Libobject.classify_function  = classify_Function;
       Libobject.subst_function = subst_Function;
       Libobject.discharge_function = discharge_Function
(*        Libobject.open_function = open_Function; *)
    }



(* Synchronisation with reset *)
let freeze () =
  !from_function,!from_graph
let unfreeze (functions,graphs) =
(*   Pp.msgnl (str "unfreezing function_table : " ++ pr_table l); *)
  from_function := functions;
  from_graph := graphs

let init () =
(*   Pp.msgnl (str "reseting function_table");  *)
  from_function := Cmap.empty;
  from_graph := Indmap.empty

let _ =
  Summary.declare_summary "functions_db_sum"
    { Summary.freeze_function = freeze;
      Summary.unfreeze_function = unfreeze;
      Summary.init_function = init }

let find_or_none id =
  try Some
    (match Nametab.locate (qualid_of_ident id) with ConstRef c -> c | _ -> Errors.anomaly "Not a constant"
    )
  with Not_found -> None



let find_Function_infos f =
  Cmap.find f !from_function


let find_Function_of_graph ind =
  Indmap.find ind !from_graph

let update_Function finfo =
(*   Pp.msgnl (pr_info finfo); *)
  Lib.add_anonymous_leaf (in_Function finfo)


let add_Function is_general f =
  let f_id = id_of_label (con_label f) in
  let equation_lemma = find_or_none (mk_equation_id f_id)
  and correctness_lemma = find_or_none (mk_correct_id f_id)
  and completeness_lemma = find_or_none (mk_complete_id f_id)
  and rect_lemma = find_or_none (Nameops.add_suffix f_id "_rect")
  and rec_lemma = find_or_none (Nameops.add_suffix f_id "_rec")
  and prop_lemma = find_or_none (Nameops.add_suffix f_id "_ind")
  and graph_ind =
    match Nametab.locate (qualid_of_ident (mk_rel_id f_id))
    with | IndRef ind -> ind | _ -> Errors.anomaly "Not an inductive"
  in
  let finfos =
    { function_constant = f;
      equation_lemma = equation_lemma;
      completeness_lemma = completeness_lemma;
      correctness_lemma = correctness_lemma;
      rect_lemma = rect_lemma;
      rec_lemma = rec_lemma;
      prop_lemma = prop_lemma;
      graph_ind = graph_ind;
      is_general = is_general

    }
  in
  update_Function finfos

let pr_table () = pr_table !from_function
(*********************************)
(* Debuging *)
let functional_induction_rewrite_dependent_proofs = ref true
let function_debug = ref false
open Goptions

let functional_induction_rewrite_dependent_proofs_sig = 
  {
    optsync = false;
    optdepr = false;
    optname = "Functional Induction Rewrite Dependent";
    optkey =  ["Functional";"Induction";"Rewrite";"Dependent"];
    optread = (fun () -> !functional_induction_rewrite_dependent_proofs);
    optwrite = (fun b -> functional_induction_rewrite_dependent_proofs := b)
  }
let _ = declare_bool_option functional_induction_rewrite_dependent_proofs_sig

let do_rewrite_dependent () = !functional_induction_rewrite_dependent_proofs = true

let function_debug_sig =
  {
    optsync = false;
    optdepr = false;
    optname = "Function debug";
    optkey =  ["Function_debug"];
    optread = (fun () -> !function_debug);
    optwrite = (fun b -> function_debug := b)
  }

let _ = declare_bool_option function_debug_sig


let do_observe () = !function_debug 



let strict_tcc = ref false
let is_strict_tcc () = !strict_tcc
let strict_tcc_sig =
  {
    optsync = false;
    optdepr = false;
    optname = "Raw Function Tcc";
    optkey =  ["Function_raw_tcc"];
    optread = (fun () -> !strict_tcc);
    optwrite = (fun b -> strict_tcc := b)
  }

let _ = declare_bool_option strict_tcc_sig


exception Building_graph of exn
exception Defining_principle of exn
exception ToShow of exn

let init_constant dir s =
  try
    Coqlib.gen_constant "Function" dir s
  with e -> raise (ToShow e)

let jmeq () =
  try
    (Coqlib.check_required_library ["Coq";"Logic";"JMeq"];
     init_constant ["Logic";"JMeq"] "JMeq")
  with e -> raise (ToShow e)

let jmeq_rec () =
  try
    Coqlib.check_required_library ["Coq";"Logic";"JMeq"];
	  init_constant ["Logic";"JMeq"] "JMeq_rec"
  with e -> raise (ToShow e)

let jmeq_refl () =
  try
    Coqlib.check_required_library ["Coq";"Logic";"JMeq"];
    init_constant ["Logic";"JMeq"] "JMeq_refl"
  with e -> raise (ToShow e)

let h_intros l =
  tclMAP h_intro l

let h_id = id_of_string "h"
let hrec_id = id_of_string "hrec"
let well_founded = function () -> (coq_constant "well_founded")
let acc_rel = function () -> (coq_constant "Acc")
let acc_inv_id = function () -> (coq_constant "Acc_inv")
let well_founded_ltof = function () ->  (Coqlib.coq_constant "" ["Arith";"Wf_nat"] "well_founded_ltof")
let ltof_ref = function  () -> (find_reference ["Coq";"Arith";"Wf_nat"] "ltof")

let evaluable_of_global_reference r = (* Tacred.evaluable_of_global_reference (Global.env ()) *)
  match r with
      ConstRef sp -> EvalConstRef sp
    | VarRef id -> EvalVarRef id
    | _ -> assert false;;

let list_rewrite (rev:bool) (eqs: (constr*bool) list) =
  tclREPEAT
    (List.fold_right
       (fun (eq,b) i -> tclORELSE ((if b then Equality.rewriteLR else Equality.rewriteRL) eq) i)
       (if rev then (List.rev eqs) else eqs) (tclFAIL 0 (mt())));;
