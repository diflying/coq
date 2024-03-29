(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2010     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

open Pp
open Errors
open Names
open Libnames
open Glob_term
open Term
open Mod_subst

(** Topconstr: definitions of [aconstr] et [constr_expr] *)

(** {6 aconstr } *)
(** This is the subtype of glob_constr allowed in syntactic extensions 
   No location since intended to be substituted at any place of a text 
   Complex expressions such as fixpoints and cofixpoints are excluded, 
   non global expressions such as existential variables also *)

type aconstr =
  (** Part common to [glob_constr] and [cases_pattern] *)
  | ARef of global_reference
  | AVar of identifier
  | AApp of aconstr * aconstr list
  | AHole of Evd.hole_kind
  | AList of identifier * identifier * aconstr * aconstr * bool
  (** Part only in [glob_constr] *)
  | ALambda of name * aconstr * aconstr
  | AProd of name * aconstr * aconstr
  | ABinderList of identifier * identifier * aconstr * aconstr
  | ALetIn of name * aconstr * aconstr
  | ACases of case_style * aconstr option *
      (aconstr * (name * (inductive * name list) option)) list *
      (cases_pattern list * aconstr) list
  | ALetTuple of name list * (name * aconstr option) * aconstr * aconstr
  | AIf of aconstr * (name * aconstr option) * aconstr * aconstr
  | ARec of fix_kind * identifier array *
      (name * aconstr option * aconstr) list array * aconstr array *
      aconstr array
  | ASort of glob_sort
  | APatVar of patvar
  | ACast of aconstr * aconstr cast_type

type scope_name = string

type tmp_scope_name = scope_name

type subscopes = tmp_scope_name option * scope_name list

(** Type of the meta-variables of an aconstr: in a recursive pattern x..y,
    x carries the sequence of objects bound to the list x..y  *)
type notation_var_instance_type =
  | NtnTypeConstr | NtnTypeConstrList | NtnTypeBinderList

(** Type of variables when interpreting a constr_expr as an aconstr:
    in a recursive pattern x..y, both x and y carry the individual type
    of each element of the list x..y *)
type notation_var_internalization_type =
  | NtnInternTypeConstr | NtnInternTypeBinder | NtnInternTypeIdent

(** This characterizes to what a notation is interpreted to *)
type interpretation =
    (identifier * (subscopes * notation_var_instance_type)) list * aconstr

(** Translate a glob_constr into a notation given the list of variables
    bound by the notation; also interpret recursive patterns           *)

val aconstr_of_glob_constr :
  (identifier * notation_var_internalization_type) list ->
  (identifier * identifier) list -> glob_constr -> aconstr

(** Name of the special identifier used to encode recursive notations  *)
val ldots_var : identifier

(** Equality of glob_constr (warning: only partially implemented) *)
val eq_glob_constr : glob_constr -> glob_constr -> bool

(** Re-interpret a notation as a glob_constr, taking care of binders     *)

val glob_constr_of_aconstr_with_binders : loc ->
  ('a -> name -> 'a * name) ->
  ('a -> aconstr -> glob_constr) -> 'a -> aconstr -> glob_constr

val glob_constr_of_aconstr : loc -> aconstr -> glob_constr

(** [match_aconstr] matches a glob_constr against a notation interpretation;
    raise [No_match] if the matching fails   *)

exception No_match

val match_aconstr : bool -> glob_constr -> interpretation ->
      (glob_constr * subscopes) list * (glob_constr list * subscopes) list *
      (glob_decl list * subscopes) list

val match_aconstr_cases_pattern :  cases_pattern -> interpretation ->
      ((cases_pattern * subscopes) list * (cases_pattern list * subscopes) list) * (cases_pattern list)

(** Substitution of kernel names in interpretation data                *)

val subst_interpretation : substitution -> interpretation -> interpretation

(** {6 Concrete syntax for terms }                                        *)

type notation = string

type explicitation = ExplByPos of int * identifier option | ExplByName of identifier

type binder_kind =
  | Default of binding_kind
  | Generalized of binding_kind * binding_kind * bool
      (** Inner binding, outer bindings, typeclass-specific flag
	 for implicit generalization of superclasses *)

type abstraction_kind = AbsLambda | AbsPi

type proj_flag = int option (** [Some n] = proj of the n-th visible argument *)

type prim_token = Numeral of Bigint.bigint | String of string

type cases_pattern_expr =
  | CPatAlias of loc * cases_pattern_expr * identifier
  | CPatCstr of loc * reference * cases_pattern_expr list
  | CPatCstrExpl of loc * reference * cases_pattern_expr list
  | CPatAtom of loc * reference option
  | CPatOr of loc * cases_pattern_expr list
  | CPatNotation of loc * notation * cases_pattern_notation_substitution
  | CPatPrim of loc * prim_token
  | CPatRecord of loc * (reference * cases_pattern_expr) list
  | CPatDelimiters of loc * string * cases_pattern_expr

and cases_pattern_notation_substitution =
    cases_pattern_expr list *     (** for constr subterms *)
    cases_pattern_expr list list  (** for recursive notations *)

type constr_expr =
  | CRef of reference
  | CFix of loc * identifier located * fix_expr list
  | CCoFix of loc * identifier located * cofix_expr list
  | CProdN of loc * (name located list * binder_kind * constr_expr) list * constr_expr
  | CLambdaN of loc * (name located list * binder_kind * constr_expr) list * constr_expr
  | CLetIn of loc * name located * constr_expr * constr_expr
  | CAppExpl of loc * (proj_flag * reference) * constr_expr list
  | CApp of loc * (proj_flag * constr_expr) *
      (constr_expr * explicitation located option) list
  | CRecord of loc * constr_expr option * (reference * constr_expr) list
  | CCases of loc * case_style * constr_expr option *
      (constr_expr * (name located option * cases_pattern_expr option)) list *
      (loc * cases_pattern_expr list located list * constr_expr) list
  | CLetTuple of loc * name located list * (name located option * constr_expr option) *
      constr_expr * constr_expr
  | CIf of loc * constr_expr * (name located option * constr_expr option)
      * constr_expr * constr_expr
  | CHole of loc * Evd.hole_kind option
  | CPatVar of loc * (bool * patvar)
  | CEvar of loc * existential_key * constr_expr list option
  | CSort of loc * glob_sort
  | CCast of loc * constr_expr * constr_expr cast_type
  | CNotation of loc * notation * constr_notation_substitution
  | CGeneralization of loc * binding_kind * abstraction_kind option * constr_expr
  | CPrim of loc * prim_token
  | CDelimiters of loc * string * constr_expr

and fix_expr =
    identifier located * (identifier located option * recursion_order_expr) * local_binder list * constr_expr * constr_expr

and cofix_expr =
    identifier located * local_binder list * constr_expr * constr_expr

and recursion_order_expr =
  | CStructRec
  | CWfRec of constr_expr
  | CMeasureRec of constr_expr * constr_expr option (** measure, relation *)

(** Anonymous defs allowed ?? *)
and local_binder =
  | LocalRawDef of name located * constr_expr
  | LocalRawAssum of name located list * binder_kind * constr_expr

and constr_notation_substitution =
    constr_expr list *      (** for constr subterms *)
    constr_expr list list * (** for recursive notations *)
    local_binder list list (** for binders subexpressions *)

type typeclass_constraint = name located * binding_kind * constr_expr

and typeclass_context = typeclass_constraint list

type constr_pattern_expr = constr_expr

val oldfashion_patterns : bool ref

(** Utilities on constr_expr                                           *)

val constr_loc : constr_expr -> loc

val cases_pattern_expr_loc : cases_pattern_expr -> loc

val local_binders_loc : local_binder list -> loc

val replace_vars_constr_expr :
  (identifier * identifier) list -> constr_expr -> constr_expr

val free_vars_of_constr_expr : constr_expr -> Idset.t
val occur_var_constr_expr : identifier -> constr_expr -> bool

val default_binder_kind : binder_kind

(** Specific function for interning "in indtype" syntax of "match" *)
val ids_of_cases_indtype : cases_pattern_expr -> identifier list

val mkIdentC : identifier -> constr_expr
val mkRefC : reference -> constr_expr
val mkAppC : constr_expr * constr_expr list -> constr_expr
val mkCastC : constr_expr * constr_expr cast_type -> constr_expr
val mkLambdaC : name located list * binder_kind * constr_expr * constr_expr -> constr_expr
val mkLetInC : name located * constr_expr * constr_expr -> constr_expr
val mkProdC : name located list * binder_kind * constr_expr * constr_expr -> constr_expr

val coerce_reference_to_id : reference -> identifier
val coerce_to_id : constr_expr -> identifier located
val coerce_to_name : constr_expr -> name located

val split_at_annot : local_binder list -> identifier located option -> local_binder list * local_binder list

val abstract_constr_expr : constr_expr -> local_binder list -> constr_expr
val prod_constr_expr : constr_expr -> local_binder list -> constr_expr

(** Same as [abstract_constr_expr] and [prod_constr_expr], with location *)
val mkCLambdaN : loc -> local_binder list -> constr_expr -> constr_expr
val mkCProdN : loc -> local_binder list -> constr_expr -> constr_expr

(** For binders parsing *)

(** With let binders *)
val names_of_local_binders : local_binder list -> name located list

(** Does not take let binders into account *)
val names_of_local_assums : local_binder list -> name located list

(** Used in typeclasses *)

val fold_constr_expr_with_binders : (identifier -> 'a -> 'a) ->
   ('a -> 'b -> constr_expr -> 'b) -> 'a -> 'b -> constr_expr -> 'b

(** Used in correctness and interface; absence of var capture not guaranteed 
   in pattern-matching clauses and in binders of the form [x,y:T(x)] *)

val map_constr_expr_with_binders :
  (identifier -> 'a -> 'a) -> ('a -> constr_expr -> constr_expr) ->
      'a -> constr_expr -> constr_expr

(** Concrete syntax for modules and module types                       *)

type with_declaration_ast =
  | CWith_Module of identifier list located * qualid located
  | CWith_Definition of identifier list located * constr_expr

type module_ast =
  | CMident of qualid located
  | CMapply of loc * module_ast * module_ast
  | CMwith of loc * module_ast * with_declaration_ast

val ntn_loc :
  loc -> constr_notation_substitution -> string -> (int * int) list
val patntn_loc :
  loc -> cases_pattern_notation_substitution -> string -> (int * int) list

(** For cases pattern parsing errors *)

val error_invalid_pattern_notation : Pp.loc -> 'a
