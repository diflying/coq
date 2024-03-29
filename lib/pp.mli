(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2010     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

open Pp_control
open Compat

(** Modify pretty printing functions behavior for PGIP/emacs output.
    This function should called once in module [Options], that's all. *)
val make_pp_emacs:unit -> unit
val make_pp_normal:unit -> unit
val make_pp_pgip:unit -> unit

(** Pretty-printers. *)

type ppcmd

type std_ppcmds = ppcmd Stream.t

(** {6 Formatting commands. } *)

val str  : string -> std_ppcmds
val stras : int * string -> std_ppcmds
val brk : int * int -> std_ppcmds
val tbrk : int * int -> std_ppcmds
val tab : unit -> std_ppcmds
val fnl : unit -> std_ppcmds
val pifb : unit -> std_ppcmds
val ws : int -> std_ppcmds
val mt : unit -> std_ppcmds
val ismt : std_ppcmds -> bool

val comment : int -> std_ppcmds
val comments : ((int * int) * string) list ref

(** {6 Concatenation. } *)

val (++) : std_ppcmds -> std_ppcmds -> std_ppcmds

(** {6 Derived commands. } *)

val spc : unit -> std_ppcmds
val cut : unit -> std_ppcmds
val align : unit -> std_ppcmds
val int : int -> std_ppcmds
val real : float -> std_ppcmds
val bool : bool -> std_ppcmds
val qstring : string -> std_ppcmds
val qs : string -> std_ppcmds
val quote : std_ppcmds -> std_ppcmds
val strbrk : string -> std_ppcmds

val xmlescape : ppcmd -> ppcmd

(** {6 Boxing commands. } *)

val h : int -> std_ppcmds -> std_ppcmds
val v : int -> std_ppcmds -> std_ppcmds
val hv : int -> std_ppcmds -> std_ppcmds
val hov : int -> std_ppcmds -> std_ppcmds
val t : std_ppcmds -> std_ppcmds

(** {6 Opening and closing of boxes. } *)

val hb : int -> std_ppcmds
val vb : int -> std_ppcmds
val hvb : int -> std_ppcmds
val hovb : int -> std_ppcmds
val tb : unit -> std_ppcmds
val close : unit -> std_ppcmds
val tclose : unit -> std_ppcmds

(** {6 PGIP commands. } *)

val tag : string -> (string * string) list -> std_ppcmds -> std_ppcmds
val open_tag : string -> (string * string) list -> std_ppcmds
val close_tag : string -> std_ppcmds (* not maintaining tag stack *)

(** {6 Pretty-printing functions {% \emph{%}without flush{% }%}. } *)

val pp_with : Format.formatter -> std_ppcmds -> unit
val ppnl_with : Format.formatter -> std_ppcmds -> unit
val warning_with : Format.formatter -> string -> unit
val warn_with : Format.formatter -> std_ppcmds -> unit
val pp_flush_with : Format.formatter -> unit -> unit

val set_warning_function : (Format.formatter -> std_ppcmds -> unit) -> unit

(** {6 Pretty-printing functions {% \emph{%}with flush{% }%}. } *)

val msg_with : Format.formatter -> std_ppcmds -> unit
val msgnl_with : Format.formatter -> std_ppcmds -> unit


(** {6 ... } *)
(** The following functions are instances of the previous ones on
  [std_ft] and [err_ft]. *)

(** {6 Pretty-printing functions {% \emph{%}without flush{% }%} on [stdout] and [stderr]. } *)

val pp : std_ppcmds -> unit
val ppnl : std_ppcmds -> unit
val pperr : std_ppcmds -> unit
val pperrnl : std_ppcmds -> unit
val message : string -> unit       (** = pPNL *)
val warning : string -> unit
val warn : std_ppcmds -> unit
val pp_flush : unit -> unit
val flush_all: unit -> unit

(** {6 Pretty-printing functions {% \emph{%}with flush{% }%} on [stdout] and [stderr]. } *)

val msg : std_ppcmds -> unit
val msgnl : std_ppcmds -> unit
val msgerr : std_ppcmds -> unit
val msgerrnl : std_ppcmds -> unit
val msg_warning : std_ppcmds -> unit

(** Same specific display in emacs as warning, but without the "Warning:" **)
val msg_debug : std_ppcmds -> unit

val string_of_ppcmds : std_ppcmds -> string

(** {6 Location management. } *)

type loc = Loc.t
val unloc : loc -> int * int
val make_loc : int * int -> loc
val dummy_loc : loc
val join_loc : loc -> loc -> loc

type 'a located = loc * 'a
val located_fold_left : ('a -> 'b -> 'a) -> 'a -> 'b located -> 'a
val located_iter2 : ('a -> 'b -> unit) -> 'a located -> 'b located -> unit
val down_located : ('a -> 'b) -> 'a located -> 'b

(** {6 Util copy/paste. } *)

val pr_comma : unit -> std_ppcmds
val pr_semicolon : unit -> std_ppcmds
val pr_bar : unit -> std_ppcmds
val pr_arg : ('a -> std_ppcmds) -> 'a -> std_ppcmds
val pr_opt : ('a -> std_ppcmds) -> 'a option -> std_ppcmds
val pr_opt_no_spc : ('a -> std_ppcmds) -> 'a option -> std_ppcmds
val pr_nth : int -> std_ppcmds

val prlist : ('a -> std_ppcmds) -> 'a list -> std_ppcmds

(** unlike all other functions below, [prlist] works lazily.
   if a strict behavior is needed, use [prlist_strict] instead. *)
val prlist_strict :  ('a -> std_ppcmds) -> 'a list -> std_ppcmds
val prlist_with_sep :
   (unit -> std_ppcmds) -> ('b -> std_ppcmds) -> 'b list -> std_ppcmds
val prvect : ('a -> std_ppcmds) -> 'a array -> std_ppcmds
val prvecti : (int -> 'a -> std_ppcmds) -> 'a array -> std_ppcmds
val prvect_with_sep :
   (unit -> std_ppcmds) -> ('a -> std_ppcmds) -> 'a array -> std_ppcmds
val prvecti_with_sep :
   (unit -> std_ppcmds) -> (int -> 'a -> std_ppcmds) -> 'a array -> std_ppcmds
val pr_vertical_list : ('b -> std_ppcmds) -> 'b list -> std_ppcmds
val pr_enum : ('a -> std_ppcmds) -> 'a list -> std_ppcmds
val pr_located : ('a -> std_ppcmds) -> 'a located -> std_ppcmds
val pr_sequence : ('a -> std_ppcmds) -> 'a list -> std_ppcmds
val surround : std_ppcmds -> std_ppcmds
