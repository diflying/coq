(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2010     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(** This module contains numerous utility functions on strings, lists,
   arrays, etc. *)

(** Mapping under pairs *)

val on_fst : ('a -> 'b) -> 'a * 'c -> 'b * 'c
val on_snd : ('a -> 'b) -> 'c * 'a -> 'c * 'b
val map_pair : ('a -> 'b) -> 'a * 'a -> 'b * 'b

(** Going down pairs *)

val down_fst : ('a -> 'b) -> 'a * 'c -> 'b
val down_snd : ('a -> 'b) -> 'c * 'a -> 'b

(** Mapping under triple *)

val on_pi1 : ('a -> 'b) -> 'a * 'c * 'd -> 'b * 'c * 'd
val on_pi2 : ('a -> 'b) -> 'c * 'a * 'd -> 'c * 'b * 'd
val on_pi3 : ('a -> 'b) -> 'c * 'd * 'a -> 'c * 'd * 'b

(** {6 Projections from triplets } *)

val pi1 : 'a * 'b * 'c -> 'a
val pi2 : 'a * 'b * 'c -> 'b
val pi3 : 'a * 'b * 'c -> 'c

(** {6 Chars. } *)

val is_letter : char -> bool
val is_digit : char -> bool
val is_ident_tail : char -> bool
val is_blank : char -> bool
val next_utf8 : string -> int -> int * int

(** {6 Strings. } *)

val explode : string -> string list
val implode : string list -> string
val strip : string -> string
val drop_simple_quotes : string -> string
val string_index_from : string -> int -> string -> int
val string_string_contains : where:string -> what:string -> bool
val plural : int -> string -> string
val ordinal : int -> string
val split_string_at : char -> string -> string list

val parse_loadpath : string -> string list

module Stringset : Set.S with type elt = string
module Stringmap : Map.S with type key = string

type utf8_status = UnicodeLetter | UnicodeIdentPart | UnicodeSymbol

exception UnsupportedUtf8

val ident_refutation : string -> string option
val classify_unicode : int -> utf8_status
val lowercase_first_char_utf8 : string -> string
val ascii_of_ident : string -> string

(** {6 Lists. } *)

val list_compare : ('a -> 'a -> int) -> 'a list -> 'a list -> int
val list_equal : ('a -> 'a -> bool) -> 'a list -> 'a list -> bool
val list_add_set : 'a -> 'a list -> 'a list
val list_eq_set : 'a list -> 'a list -> bool
val list_intersect : 'a list -> 'a list -> 'a list
val list_union : 'a list -> 'a list -> 'a list
val list_unionq : 'a list -> 'a list -> 'a list
val list_subtract : 'a list -> 'a list -> 'a list
val list_subtractq : 'a list -> 'a list -> 'a list

(** [list_tabulate f n] builds [[f 0; ...; f (n-1)]] *)
val list_tabulate : (int -> 'a) -> int -> 'a list
val list_make : int -> 'a -> 'a list
val list_assign : 'a list -> int -> 'a -> 'a list
val list_distinct : 'a list -> bool
val list_duplicates : 'a list -> 'a list
val list_filter2 : ('a -> 'b -> bool) -> 'a list * 'b list -> 'a list * 'b list
val list_map_filter : ('a -> 'b option) -> 'a list -> 'b list
val list_map_filter_i : (int -> 'a -> 'b option) -> 'a list -> 'b list
val list_filter_with : bool list -> 'a list -> 'a list
val list_filter_along : ('a -> bool) -> 'a list -> 'b list -> 'b list

(** [list_smartmap f [a1...an] = List.map f [a1...an]] but if for all i
   [ f ai == ai], then [list_smartmap f l==l] *)
val list_smartmap : ('a -> 'a) -> 'a list -> 'a list
val list_map_left : ('a -> 'b) -> 'a list -> 'b list
val list_map_i : (int -> 'a -> 'b) -> int -> 'a list -> 'b list
val list_map2_i :
  (int -> 'a -> 'b -> 'c) -> int -> 'a list -> 'b list -> 'c list
val list_map3 :
  ('a -> 'b -> 'c -> 'd) -> 'a list -> 'b list -> 'c list -> 'd list
val list_map4 :
  ('a -> 'b -> 'c -> 'd -> 'e) -> 'a list -> 'b list -> 'c list -> 'd list -> 'e list
val list_map_to_array : ('a -> 'b) -> 'a list -> 'b array
val list_filter_i :
  (int -> 'a -> bool) -> 'a list -> 'a list

(** [list_smartfilter f [a1...an] = List.filter f [a1...an]] but if for all i
   [f ai = true], then [list_smartfilter f l==l] *)
val list_smartfilter : ('a -> bool) -> 'a list -> 'a list

(** [list_index] returns the 1st index of an element in a list (counting from 1) *)
val list_index : 'a -> 'a list -> int
val list_index_f : ('a -> 'a -> bool) -> 'a -> 'a list -> int

(** [list_unique_index x l] returns [Not_found] if [x] doesn't occur exactly once *)
val list_unique_index : 'a -> 'a list -> int

(** [list_index0] behaves as [list_index] except that it starts counting at 0 *)
val list_index0 : 'a -> 'a list -> int
val list_index0_f : ('a -> 'a -> bool) -> 'a -> 'a list -> int
val list_iter3 : ('a -> 'b -> 'c -> unit) -> 'a list -> 'b list -> 'c list -> unit
val list_iter_i :  (int -> 'a -> unit) -> 'a list -> unit
val list_fold_right_i :  (int -> 'a -> 'b -> 'b) -> int -> 'a list -> 'b -> 'b
val list_fold_left_i :  (int -> 'a -> 'b -> 'a) -> int -> 'a -> 'b list -> 'a
val list_fold_right_and_left :
    ('a -> 'b -> 'b list -> 'a) -> 'b list -> 'a -> 'a
val list_fold_left3 : ('a -> 'b -> 'c -> 'd -> 'a) -> 'a -> 'b list -> 'c list -> 'd list -> 'a
val list_for_all_i : (int -> 'a -> bool) -> int -> 'a list -> bool
val list_except : 'a -> 'a list -> 'a list
val list_remove : 'a -> 'a list -> 'a list
val list_remove_first : 'a -> 'a list -> 'a list
val list_remove_assoc_in_triple : 'a -> ('a * 'b * 'c) list -> ('a * 'b * 'c) list
val list_assoc_snd_in_triple : 'a -> ('a * 'b * 'c) list -> 'b
val list_for_all2eq : ('a -> 'b -> bool) -> 'a list -> 'b list -> bool
val list_sep_last : 'a list -> 'a * 'a list
val list_try_find_i : (int -> 'a -> 'b) -> int -> 'a list -> 'b
val list_try_find : ('a -> 'b) -> 'a list -> 'b
val list_uniquize : 'a list -> 'a list

(** merges two sorted lists and preserves the uniqueness property: *)
val list_merge_uniq : ('a -> 'a -> int) -> 'a list -> 'a list -> 'a list
val list_subset : 'a list -> 'a list -> bool
val list_chop : int -> 'a list -> 'a list * 'a list
(* former [list_split_at] was a duplicate of [list_chop] *)
val list_split_when : ('a -> bool) -> 'a list -> 'a list * 'a list
val list_split_by : ('a -> bool) -> 'a list -> 'a list * 'a list
val list_split3 : ('a * 'b * 'c) list -> 'a list * 'b list * 'c list
val list_partition_by : ('a -> 'a -> bool) -> 'a list -> 'a list list
val list_firstn : int -> 'a list -> 'a list
val list_last : 'a list -> 'a
val list_lastn : int -> 'a list -> 'a list
val list_skipn : int -> 'a list -> 'a list
val list_skipn_at_least : int -> 'a list -> 'a list
val list_addn : int -> 'a -> 'a list -> 'a list
val list_prefix_of : 'a list -> 'a list -> bool

(** [list_drop_prefix p l] returns [t] if [l=p++t] else return [l] *)
val list_drop_prefix : 'a list -> 'a list -> 'a list
val list_drop_last : 'a list -> 'a list

(** [map_append f [x1; ...; xn]] returns [(f x1)@(f x2)@...@(f xn)] *)
val list_map_append : ('a -> 'b list) -> 'a list -> 'b list
val list_join_map : ('a -> 'b list) -> 'a list -> 'b list

(** raises [Invalid_argument] if the two lists don't have the same length *)
val list_map_append2 : ('a -> 'b -> 'c list) -> 'a list -> 'b list -> 'c list
val list_share_tails : 'a list -> 'a list -> 'a list * 'a list * 'a list

(** [list_fold_map f e_0 [l_1...l_n] = e_n,[k_1...k_n]]
   where [(e_i,k_i)=f e_{i-1} l_i] *)
val list_fold_map : ('a -> 'b -> 'a * 'c) -> 'a -> 'b list -> 'a * 'c list
val list_fold_map' : ('b -> 'a -> 'c * 'a) -> 'b list -> 'a -> 'c list * 'a
val list_map_assoc : ('a -> 'b) -> ('c * 'a) list -> ('c * 'b) list
val list_assoc_f : ('a -> 'a -> bool) -> 'a -> ('a * 'b) list -> 'b

(** A generic cartesian product: for any operator (**),
   [list_cartesian (**) [x1;x2] [y1;y2] = [x1**y1; x1**y2; x2**y1; x2**y1]],
   and so on if there are more elements in the lists. *)
val list_cartesian : ('a -> 'b -> 'c) -> 'a list -> 'b list -> 'c list

(** [list_cartesians] is an n-ary cartesian product: it iterates
   [list_cartesian] over a list of lists.  *)
val list_cartesians : ('a -> 'b -> 'b) -> 'b -> 'a list list -> 'b list

(** list_combinations [[a;b];[c;d]] returns [[a;c];[a;d];[b;c];[b;d]] *)
val list_combinations : 'a list list -> 'a list list
val list_combine3 : 'a list -> 'b list -> 'c list -> ('a * 'b * 'c) list

(** Keep only those products that do not return None *)
val list_cartesian_filter :
  ('a -> 'b -> 'c option) -> 'a list -> 'b list -> 'c list
val list_cartesians_filter :
  ('a -> 'b -> 'b option) -> 'b -> 'a list list -> 'b list

val list_union_map : ('a -> 'b -> 'b) -> 'a list -> 'b -> 'b
val list_factorize_left : ('a * 'b) list -> ('a * 'b list) list

(** {6 Arrays. } *)

val array_compare : ('a -> 'a -> int) -> 'a array -> 'a array -> int
val array_equal : ('a -> 'a -> bool) -> 'a array -> 'a array -> bool
val array_exists : ('a -> bool) -> 'a array -> bool
val array_for_all : ('a -> bool) -> 'a array -> bool
val array_for_all2 : ('a -> 'b -> bool) -> 'a array -> 'b array -> bool
val array_for_all3 : ('a -> 'b -> 'c -> bool) ->
  'a array -> 'b array -> 'c array -> bool
val array_for_all4 : ('a -> 'b -> 'c -> 'd -> bool) ->
  'a array -> 'b array -> 'c array -> 'd array -> bool
val array_for_all_i : (int -> 'a -> bool) -> int -> 'a array -> bool
val array_find_i : (int -> 'a -> bool) -> 'a array -> int option
val array_hd : 'a array -> 'a
val array_tl : 'a array -> 'a array
val array_last : 'a array -> 'a
val array_cons : 'a -> 'a array -> 'a array
val array_rev : 'a array -> unit
val array_fold_right_i :
  (int -> 'b -> 'a -> 'a) -> 'b array -> 'a -> 'a
val array_fold_left_i : (int -> 'a -> 'b -> 'a) -> 'a -> 'b array -> 'a
val array_fold_right2 :
  ('a -> 'b -> 'c -> 'c) -> 'a array -> 'b array -> 'c -> 'c
val array_fold_left2 :
  ('a -> 'b -> 'c -> 'a) -> 'a -> 'b array -> 'c array -> 'a
val array_fold_left3 :
  ('a -> 'b -> 'c -> 'd -> 'a) -> 'a -> 'b array -> 'c array -> 'd array -> 'a
val array_fold_left2_i :
  (int -> 'a -> 'b -> 'c -> 'a) -> 'a -> 'b array -> 'c array -> 'a
val array_fold_left_from : int -> ('a -> 'b -> 'a) -> 'a -> 'b array -> 'a
val array_fold_right_from : int -> ('a -> 'b -> 'b) -> 'a array -> 'b -> 'b
val array_app_tl : 'a array -> 'a list -> 'a list
val array_list_of_tl : 'a array -> 'a list
val array_map_to_list : ('a -> 'b) -> 'a array -> 'b list
val array_chop : int -> 'a array -> 'a array * 'a array
val array_smartmap : ('a -> 'a) -> 'a array -> 'a array
val array_map2 : ('a -> 'b -> 'c) -> 'a array -> 'b array -> 'c array
val array_map2_i : (int -> 'a -> 'b -> 'c) -> 'a array -> 'b array -> 'c array
val array_map3 :
  ('a -> 'b -> 'c -> 'd) -> 'a array -> 'b array -> 'c array -> 'd array
val array_map_left : ('a -> 'b) -> 'a array -> 'b array
val array_map_left_pair : ('a -> 'b) -> 'a array -> ('c -> 'd) -> 'c array ->
  'b array * 'd array
val array_iter2 : ('a -> 'b -> unit) -> 'a array -> 'b array -> unit
val array_fold_map' : ('a -> 'c -> 'b * 'c) -> 'a array -> 'c -> 'b array * 'c
val array_fold_map : ('a -> 'b -> 'a * 'c) -> 'a -> 'b array -> 'a * 'c array
val array_fold_map2' :
  ('a -> 'b -> 'c -> 'd * 'c) -> 'a array -> 'b array -> 'c -> 'd array * 'c
val array_distinct : 'a array -> bool
val array_union_map : ('a -> 'b -> 'b) -> 'a array -> 'b -> 'b
val array_rev_to_list : 'a array -> 'a list
val array_filter_along : ('a -> bool) -> 'a list -> 'b array -> 'b array
val array_filter_with : bool list -> 'a array -> 'a array

(** {6 Streams. } *)

val stream_nth : int -> 'a Stream.t -> 'a
val stream_njunk : int -> 'a Stream.t -> unit

(** {6 Matrices. } *)

val matrix_transpose : 'a list list -> 'a list list

(** {6 Functions. } *)

val identity : 'a -> 'a
val compose : ('a -> 'b) -> ('c -> 'a) -> 'c -> 'b
val const : 'a -> 'b -> 'a
val iterate : ('a -> 'a) -> int -> 'a -> 'a
val repeat : int -> ('a -> unit) -> 'a -> unit
val iterate_for : int -> int -> (int -> 'a -> 'a) -> 'a -> 'a
val app_opt : ('a -> 'a) option -> 'a -> 'a

(** {6 Delayed computations. } *)

type 'a delayed = unit -> 'a

val delayed_force : 'a delayed -> 'a

(** {6 Misc. } *)

type ('a,'b) union = Inl of 'a | Inr of 'b

module Intset : Set.S with type elt = int

module Intmap : Map.S with type key = int

val intmap_in_dom : int -> 'a Intmap.t -> bool
val intmap_to_list : 'a Intmap.t -> (int * 'a) list
val intmap_inv : 'a Intmap.t -> 'a -> int list

val interval : int -> int -> int list


(** In [map_succeed f l] an element [a] is removed if [f a] raises 
   [Failure _] otherwise behaves as [List.map f l] *)

val map_succeed : ('a -> 'b) -> 'a list -> 'b list

(** {6 Memoization. } *)

(** General comments on memoization:
   - cache is created whenever the function is supplied (because of
      ML's polymorphic value restriction).
   - cache is never flushed (unless the memoized fun is GC'd)
 
   One cell memory: memorizes only the last call *)
val memo1_1 : ('a -> 'b) -> ('a -> 'b)
val memo1_2 : ('a -> 'b -> 'c) -> ('a -> 'b -> 'c)

(** with custom equality (used to deal with various arities) *)
val memo1_eq : ('a -> 'a -> bool) -> ('a -> 'b) -> ('a -> 'b)

(** Memorizes the last [n] distinct calls. Efficient only for small [n]. *)
val memon_eq : ('a -> 'a -> bool) -> int -> ('a -> 'b) -> ('a -> 'b)

(** {6 Size of an ocaml value (in words, bytes and kilobytes). } *)

val size_w : 'a -> int
val size_b : 'a -> int
val size_kb : 'a -> int

(** {6 Total size of the allocated ocaml heap. } *)

val heap_size : unit -> int
val heap_size_kb : unit -> int

(** {6 ... } *)
(** Coq interruption: set the following boolean reference to interrupt Coq
    (it eventually raises [Break], simulating a Ctrl-C) *)

val interrupt : bool ref
val check_for_interrupt : unit -> unit
