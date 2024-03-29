(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2010     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

open Configwin
open Printf

let pref_file = Filename.concat Minilib.xdg_config_home "coqiderc"

let accel_file = Filename.concat Minilib.xdg_config_home "coqide.keys"

let mod_to_str (m:Gdk.Tags.modifier) =
  match m with
    | `MOD1 -> "<Alt>"
    | `MOD2 -> "<Mod2>"
    | `MOD3 -> "<Mod3>"
    | `MOD4 -> "<Mod4>"
    | `MOD5 -> "<Mod5>"
    | `CONTROL -> "<Control>"
    | `SHIFT -> "<Shift>"
    |  `BUTTON1| `BUTTON2| `BUTTON3| `BUTTON4| `BUTTON5| `LOCK -> ""

let mod_list_to_str l = List.fold_left (fun s m -> (mod_to_str m)^s) "" l

let str_to_mod_list s = snd (GtkData.AccelGroup.parse s)

type project_behavior = Ignore_args | Append_args | Subst_args

let string_of_project_behavior = function
  |Ignore_args -> "ignored"
  |Append_args -> "appended to arguments"
  |Subst_args -> "taken instead of arguments"

let project_behavior_of_string s =
  if s = "taken instead of arguments" then Subst_args
  else if s = "appended to arguments" then Append_args
  else Ignore_args

type pref =
    {
      mutable cmd_coqc : string;
      mutable cmd_make : string;
      mutable cmd_coqmakefile : string;
      mutable cmd_coqdoc : string;

      mutable global_auto_revert : bool;
      mutable global_auto_revert_delay : int;

      mutable auto_save : bool;
      mutable auto_save_delay : int;
      mutable auto_save_name : string * string;

      mutable read_project : project_behavior;
      mutable project_file_name : string;

      mutable encoding_use_locale : bool;
      mutable encoding_use_utf8 : bool;
      mutable encoding_manual : string;

      mutable automatic_tactics : string list;
      mutable cmd_print : string;

      mutable modifier_for_navigation : string;
      mutable modifier_for_templates : string;
      mutable modifier_for_tactics : string;
      mutable modifier_for_display : string;
      mutable modifiers_valid : string;

      mutable cmd_browse : string;
      mutable cmd_editor : string;

      mutable text_font : Pango.font_description;

      mutable doc_url : string;
      mutable library_url : string;

      mutable show_toolbar : bool;
      mutable contextual_menus_on_goal : bool;
      mutable window_width : int;
      mutable window_height :int;
      mutable query_window_width : int;
      mutable query_window_height : int;
(*
      mutable use_utf8_notation : bool;
*)
      mutable auto_complete : bool;
      mutable stop_before : bool;
      mutable lax_syntax : bool;
      mutable vertical_tabs : bool;
      mutable opposite_tabs : bool;

      mutable background_color : string;
      mutable processing_color : string;
      mutable processed_color : string;

}

let use_default_doc_url = "(automatic)"

let (current:pref ref) =
  ref {
    cmd_coqc = "coqc";
    cmd_make = "make";
    cmd_coqmakefile = "coq_makefile -o makefile *.v";
    cmd_coqdoc = "coqdoc -q -g";
    cmd_print = "lpr";

    global_auto_revert = false;
    global_auto_revert_delay = 10000;

    auto_save = true;
    auto_save_delay = 10000;
    auto_save_name = "#","#";

    read_project = Ignore_args;
    project_file_name = "_CoqProject";

    encoding_use_locale = true;
    encoding_use_utf8 = false;
    encoding_manual = "ISO_8859-1";

    automatic_tactics = ["trivial"; "tauto"; "auto"; "omega";
			 "auto with *"; "intuition" ];

    modifier_for_navigation = "<Control><Alt>";
    modifier_for_templates = "<Control><Shift>";
    modifier_for_tactics = "<Control><Alt>";
    modifier_for_display = "<Alt><Shift>";
    modifiers_valid = "<Alt><Control><Shift>";


    cmd_browse = Flags.browser_cmd_fmt;
    cmd_editor = if Sys.os_type = "Win32" then "NOTEPAD %s" else "emacs %s";

(*    text_font = Pango.Font.from_string "sans 12";*)
    text_font = Pango.Font.from_string (match Coq_config.gtk_platform with
					  |`QUARTZ -> "Arial Unicode MS 11"
					  |_ -> "Monospace 10");

    doc_url = Coq_config.wwwrefman;
    library_url = Coq_config.wwwstdlib;

    show_toolbar = true;
    contextual_menus_on_goal = true;
    window_width = 800;
    window_height = 600;
    query_window_width = 600;
    query_window_height = 400;
(*
    use_utf8_notation = false;
*)
    auto_complete = false;
    stop_before = true;
    lax_syntax = true;
    vertical_tabs = false;
    opposite_tabs = false;

    background_color = "cornsilk";
    processed_color = "light green";
    processing_color = "light blue";

  }


let change_font = ref (fun f -> ())

let change_background_color = ref (fun clr -> ())

let show_toolbar = ref (fun x -> ())

let auto_complete = ref (fun x -> ())

let contextual_menus_on_goal = ref (fun x -> ())

let resize_window = ref (fun () -> ())

let save_pref () =
  if not (Sys.file_exists Minilib.xdg_config_home)
  then Unix.mkdir Minilib.xdg_config_home 0o700;
  (try GtkData.AccelMap.save accel_file
  with _ -> ());
  let p = !current in

    let add = Minilib.Stringmap.add in
    let (++) x f = f x in
    Minilib.Stringmap.empty ++
    add "cmd_coqc" [p.cmd_coqc] ++
    add "cmd_make" [p.cmd_make] ++
    add "cmd_coqmakefile" [p.cmd_coqmakefile] ++
    add "cmd_coqdoc" [p.cmd_coqdoc] ++
    add "global_auto_revert" [string_of_bool p.global_auto_revert] ++
    add "global_auto_revert_delay"
      [string_of_int p.global_auto_revert_delay] ++
    add "auto_save" [string_of_bool p.auto_save] ++
    add "auto_save_delay" [string_of_int p.auto_save_delay] ++
    add "auto_save_name" [fst p.auto_save_name; snd p.auto_save_name] ++

    add "project_options" [string_of_project_behavior p.read_project] ++
    add "project_file_name" [p.project_file_name] ++

    add "encoding_use_locale" [string_of_bool p.encoding_use_locale] ++
    add "encoding_use_utf8" [string_of_bool p.encoding_use_utf8] ++
    add "encoding_manual" [p.encoding_manual] ++

    add "automatic_tactics" p.automatic_tactics ++
    add "cmd_print" [p.cmd_print] ++
    add "modifier_for_navigation" [p.modifier_for_navigation] ++
    add "modifier_for_templates" [p.modifier_for_templates] ++
    add "modifier_for_tactics" [p.modifier_for_tactics] ++
    add "modifier_for_display" [p.modifier_for_display] ++
    add "modifiers_valid" [p.modifiers_valid] ++
    add "cmd_browse" [p.cmd_browse] ++
    add "cmd_editor" [p.cmd_editor] ++

    add "text_font" [Pango.Font.to_string p.text_font] ++

    add "doc_url" [p.doc_url] ++
    add "library_url" [p.library_url] ++
    add "show_toolbar" [string_of_bool p.show_toolbar] ++
    add "contextual_menus_on_goal"
      [string_of_bool p.contextual_menus_on_goal] ++
    add "window_height" [string_of_int p.window_height] ++
    add "window_width" [string_of_int p.window_width] ++
    add "query_window_height" [string_of_int p.query_window_height] ++
    add "query_window_width" [string_of_int p.query_window_width] ++
    add "auto_complete" [string_of_bool p.auto_complete] ++
    add "stop_before" [string_of_bool p.stop_before] ++
    add "lax_syntax" [string_of_bool p.lax_syntax] ++
    add "vertical_tabs" [string_of_bool p.vertical_tabs] ++
    add "opposite_tabs" [string_of_bool p.opposite_tabs] ++
    add "background_color" [p.background_color] ++
    add "processing_color" [p.processing_color] ++
    add "processed_color" [p.processed_color] ++
    Config_lexer.print_file pref_file

let load_pref () =
  let accel_dir = List.find
    (fun x -> Sys.file_exists (Filename.concat x "coqide.keys"))
    Minilib.xdg_config_dirs in
  GtkData.AccelMap.load (Filename.concat accel_dir "coqide.keys");
  let p = !current in

    let m = Config_lexer.load_file pref_file in
    let np = { p with cmd_coqc = p.cmd_coqc } in
    let set k f = try let v = Minilib.Stringmap.find k m in f v with _ -> () in
    let set_hd k f = set k (fun v -> f (List.hd v)) in
    let set_bool k f = set_hd k (fun v -> f (bool_of_string v)) in
    let set_int k f = set_hd k (fun v -> f (int_of_string v)) in
    let set_pair k f = set k (function [v1;v2] -> f v1 v2 | _ -> raise Exit) in
    let set_command_with_pair_compat k f =
      set k (function [v1;v2] -> f (v1^"%s"^v2) | [v] -> f v | _ -> raise Exit)
    in
    set_hd "cmd_coqc" (fun v -> np.cmd_coqc <- v);
    set_hd "cmd_make" (fun v -> np.cmd_make <- v);
    set_hd "cmd_coqmakefile" (fun v -> np.cmd_coqmakefile <- v);
    set_hd "cmd_coqdoc" (fun v -> np.cmd_coqdoc <- v);
    set_bool "global_auto_revert" (fun v -> np.global_auto_revert <- v);
    set_int "global_auto_revert_delay"
      (fun v -> np.global_auto_revert_delay <- v);
    set_bool "auto_save" (fun v -> np.auto_save <- v);
    set_int "auto_save_delay" (fun v -> np.auto_save_delay <- v);
    set_pair "auto_save_name" (fun v1 v2 -> np.auto_save_name <- (v1,v2));
    set_bool "encoding_use_locale" (fun v -> np.encoding_use_locale <- v);
    set_bool "encoding_use_utf8" (fun v -> np.encoding_use_utf8 <- v);
    set_hd "encoding_manual" (fun v -> np.encoding_manual <- v);
    set_hd "project_options"
      (fun v -> np.read_project <- (project_behavior_of_string v));
    set_hd "project_file_name" (fun v -> np.project_file_name <- v);
    set "automatic_tactics"
      (fun v -> np.automatic_tactics <- v);
    set_hd "cmd_print" (fun v -> np.cmd_print <- v);
    set_hd "modifier_for_navigation"
      (fun v -> np.modifier_for_navigation <- v);
    set_hd "modifier_for_templates"
      (fun v -> np.modifier_for_templates <- v);
    set_hd "modifier_for_tactics"
      (fun v -> np.modifier_for_tactics <- v);
    set_hd "modifier_for_display"
      (fun v -> np.modifier_for_display <- v);
    set_hd "modifiers_valid"
      (fun v -> np.modifiers_valid <- v);
    set_command_with_pair_compat "cmd_browse" (fun v -> np.cmd_browse <- v);
    set_command_with_pair_compat "cmd_editor" (fun v -> np.cmd_editor <- v);
    set_hd "text_font" (fun v -> np.text_font <- Pango.Font.from_string v);
    set_hd "doc_url" (fun v ->
      if not (Flags.is_standard_doc_url v) &&
        v <> use_default_doc_url &&
	(* Extra hack to support links to last released doc version *)
        v <> Coq_config.wwwcoq ^ "doc" &&
	v <> Coq_config.wwwcoq ^ "doc/"
      then
	(*prerr_endline ("Warning: Non-standard URL for Coq documentation in preference file: "^v);*)
      np.doc_url <- v);
    set_hd "library_url" (fun v -> np.library_url <- v);
    set_bool "show_toolbar" (fun v -> np.show_toolbar <- v);
    set_bool "contextual_menus_on_goal"
      (fun v -> np.contextual_menus_on_goal <- v);
    set_int "window_width" (fun v -> np.window_width <- v);
    set_int "window_height" (fun v -> np.window_height <- v);
    set_int "query_window_width" (fun v -> np.query_window_width <- v);
    set_int "query_window_height" (fun v -> np.query_window_height <- v);
    set_bool "auto_complete" (fun v -> np.auto_complete <- v);
    set_bool "stop_before" (fun v -> np.stop_before <- v);
    set_bool "lax_syntax" (fun v -> np.lax_syntax <- v);
    set_bool "vertical_tabs" (fun v -> np.vertical_tabs <- v);
    set_bool "opposite_tabs" (fun v -> np.opposite_tabs <- v);
    set_hd "background_color" (fun v -> np.background_color <- v);
    set_hd "processing_color" (fun v -> np.processing_color <- v);
    set_hd "processed_color" (fun v -> np.processed_color <- v);
    current := np
(*
    Format.printf "in load_pref: current.text_font = %s@." (Pango.Font.to_string !current.text_font);
*)

let configure ?(apply=(fun () -> ())) () =
  let cmd_coqc =
    string
      ~f:(fun s -> !current.cmd_coqc <- s)
      "       coqc"  !current.cmd_coqc in
  let cmd_make =
    string
      ~f:(fun s -> !current.cmd_make <- s)
      "       make" !current.cmd_make in
  let cmd_coqmakefile =
    string
      ~f:(fun s -> !current.cmd_coqmakefile <- s)
      "coqmakefile" !current.cmd_coqmakefile in
  let cmd_coqdoc =
    string
      ~f:(fun s -> !current.cmd_coqdoc <- s)
      "     coqdoc" !current.cmd_coqdoc in
  let cmd_print =
    string
      ~f:(fun s -> !current.cmd_print <- s)
      "   Print ps" !current.cmd_print in

  let config_font =
    let box = GPack.hbox () in
    let w = GMisc.font_selection () in
    w#set_preview_text
      "Goal (∃n : nat, n ≤ 0)∧(∀x,y,z, x∈y⋃z↔x∈y∨x∈z).";
    box#pack ~expand:true w#coerce;
    ignore (w#misc#connect#realize
	      ~callback:(fun () -> w#set_font_name
			   (Pango.Font.to_string !current.text_font)));
    custom
      ~label:"Fonts for text"
      box
      (fun () ->
	 let fd =  w#font_name in
	 !current.text_font <- (Pango.Font.from_string fd) ;
(*
	 Format.printf "in config_font: current.text_font = %s@." (Pango.Font.to_string !current.text_font);
*)
	 !change_font !current.text_font)
      true
  in

  let config_color =
    let box = GPack.vbox () in
    let table = GPack.table
      ~row_spacings:5
      ~col_spacings:5
      ~border_width:2
      ~packing:(box#pack ~expand:true) ()
    in
    let background_label = GMisc.label
      ~text:"Background color"
      ~packing:(table#attach ~expand:`X ~left:0 ~top:0) ()
    in
    let processed_label = GMisc.label
      ~text:"Background color of processed text"
      ~packing:(table#attach ~expand:`X ~left:0 ~top:1) ()
    in
    let processing_label = GMisc.label
      ~text:"Background color of text being processed"
      ~packing:(table#attach ~expand:`X ~left:0 ~top:2) ()
    in
    let () = background_label#set_xalign 0. in
    let () = processed_label#set_xalign 0. in
    let () = processing_label#set_xalign 0. in
    let background_button = GButton.color_button
      ~color:(Tags.color_of_string (!current.background_color))
      ~packing:(table#attach ~left:1 ~top:0) ()
    in
    let processed_button = GButton.color_button
      ~color:(Tags.get_processed_color ())
      ~packing:(table#attach ~left:1 ~top:1) ()
    in
    let processing_button = GButton.color_button
      ~color:(Tags.get_processing_color ())
      ~packing:(table#attach ~left:1 ~top:2) ()
    in
    let reset_button = GButton.button
      ~label:"Reset"
      ~packing:box#pack ()
    in
    let reset_cb () =
      background_button#set_color (Tags.color_of_string "cornsilk");
      processing_button#set_color (Tags.color_of_string "light blue");
      processed_button#set_color (Tags.color_of_string "light green");
    in
    let _ = reset_button#connect#clicked ~callback:reset_cb in
    let label = "Color configuration" in
    let callback () =
      !current.background_color <- Tags.string_of_color background_button#color;
      !current.processing_color <- Tags.string_of_color processing_button#color;
      !current.processed_color <- Tags.string_of_color processed_button#color;
      !change_background_color background_button#color;
      Tags.set_processing_color processing_button#color;
      Tags.set_processed_color processed_button#color
    in
    custom ~label box callback true
  in

(*
  let show_toolbar =
    bool
      ~f:(fun s ->
	    !current.show_toolbar <- s;
	    !show_toolbar s)
      "Show toolbar" !current.show_toolbar
  in
  let window_height =
    string
    ~f:(fun s -> !current.window_height <- (try int_of_string s with _ -> 600);
	  !resize_window ();
       )
      "Window height"
      (string_of_int !current.window_height)
  in
  let window_width =
    string
    ~f:(fun s -> !current.window_width <-
	  (try int_of_string s with _ -> 800))
      "Window width"
      (string_of_int !current.window_width)
  in
*)
  let auto_complete =
    bool
      ~f:(fun s ->
	    !current.auto_complete <- s;
	    !auto_complete s)
      "Auto Complete" !current.auto_complete
  in

(*  let use_utf8_notation =
    bool
      ~f:(fun b ->
	    !current.use_utf8_notation <- b;
	 )
      "Use Unicode Notation: " !current.use_utf8_notation
  in
*)
(*
  let config_appearance = [show_toolbar; window_width; window_height] in
*)
  let global_auto_revert =
    bool
      ~f:(fun s -> !current.global_auto_revert <- s)
      "Enable global auto revert" !current.global_auto_revert
  in
  let global_auto_revert_delay =
    string
    ~f:(fun s -> !current.global_auto_revert_delay <-
	  (try int_of_string s with _ -> 10000))
      "Global auto revert delay (ms)"
      (string_of_int !current.global_auto_revert_delay)
  in

  let auto_save =
    bool
      ~f:(fun s -> !current.auto_save <- s)
      "Enable auto save" !current.auto_save
  in
  let auto_save_delay =
    string
    ~f:(fun s -> !current.auto_save_delay <-
	  (try int_of_string s with _ -> 10000))
      "Auto save delay (ms)"
      (string_of_int !current.auto_save_delay)
  in

  let stop_before =
    bool
      ~f:(fun s -> !current.stop_before <- s)
      "Stop interpreting before the current point" !current.stop_before
  in

  let lax_syntax =
    bool
      ~f:(fun s -> !current.lax_syntax <- s)
      "Relax read-only constraint at end of command" !current.lax_syntax
  in

  let vertical_tabs =
    bool
      ~f:(fun s -> !current.vertical_tabs <- s)
      "Vertical tabs" !current.vertical_tabs
  in

  let opposite_tabs =
    bool
      ~f:(fun s -> !current.opposite_tabs <- s)
      "Tabs on opposite side" !current.opposite_tabs
  in

  let encodings =
    combo
      "File charset encoding "
      ~f:(fun s ->
	    match s with
	    | "UTF-8" ->
		!current.encoding_use_utf8 <- true;
		!current.encoding_use_locale <- false
	    | "LOCALE" ->
		!current.encoding_use_utf8 <- false;
		!current.encoding_use_locale <- true
	    | _ ->
		!current.encoding_use_utf8 <- false;
		!current.encoding_use_locale <- false;
		!current.encoding_manual <- s;
	 )
      ~new_allowed: true
      ["UTF-8";"LOCALE";!current.encoding_manual]
      (if !current.encoding_use_utf8 then "UTF-8"
       else if !current.encoding_use_locale then "LOCALE" else !current.encoding_manual)
  in
  let read_project =
    combo
      "Project file options are"
      ~f:(fun s -> !current.read_project <- project_behavior_of_string s)
      ~editable:false
      [string_of_project_behavior Subst_args;
       string_of_project_behavior Append_args;
       string_of_project_behavior Ignore_args]
      (string_of_project_behavior !current.read_project)
  in
  let project_file_name =
    string "Default name for project file"
      ~f:(fun s -> !current.project_file_name <- s)
      !current.project_file_name
  in
  let help_string =
    "restart to apply"
  in
  let the_valid_mod = str_to_mod_list !current.modifiers_valid in
  let modifier_for_tactics =
    modifiers
      ~allow:the_valid_mod
      ~f:(fun l -> !current.modifier_for_tactics <- mod_list_to_str l)
      ~help:help_string
      "Modifiers for Tactics Menu"
      (str_to_mod_list !current.modifier_for_tactics)
  in
  let modifier_for_templates =
    modifiers
      ~allow:the_valid_mod
      ~f:(fun l -> !current.modifier_for_templates <- mod_list_to_str l)
      ~help:help_string
      "Modifiers for Templates Menu"
      (str_to_mod_list !current.modifier_for_templates)
  in
  let modifier_for_navigation =
    modifiers
      ~allow:the_valid_mod
      ~f:(fun l -> !current.modifier_for_navigation <- mod_list_to_str l)
      ~help:help_string
      "Modifiers for Navigation Menu"
      (str_to_mod_list !current.modifier_for_navigation)
  in
  let modifier_for_display =
    modifiers
      ~allow:the_valid_mod
      ~f:(fun l -> !current.modifier_for_display <- mod_list_to_str l)
      ~help:help_string
      "Modifiers for Display Menu"
      (str_to_mod_list !current.modifier_for_display)
  in
  let modifiers_valid =
    modifiers
      ~f:(fun l -> !current.modifiers_valid <- mod_list_to_str l)
      "Allowed modifiers"
      the_valid_mod
  in
  let cmd_editor =
    let predefined = [ "emacs %s"; "vi %s"; "NOTEPAD %s" ] in
    combo
      ~help:"(%s for file name)"
      "External editor"
      ~f:(fun s -> !current.cmd_editor <- s)
      ~new_allowed: true
      (predefined@[if List.mem !current.cmd_editor predefined then ""
                   else !current.cmd_editor])
      !current.cmd_editor
  in
  let cmd_browse =
    let predefined = [
      Coq_config.browser;
      "netscape -remote \"openURL(%s)\"";
      "mozilla -remote \"openURL(%s)\"";
      "firefox -remote \"openURL(%s,new-windows)\" || firefox %s &";
      "seamonkey -remote \"openURL(%s)\" || seamonkey %s &"
    ] in
    combo
      ~help:"(%s for url)"
      "Browser"
      ~f:(fun s -> !current.cmd_browse <- s)
      ~new_allowed: true
      (predefined@[if List.mem !current.cmd_browse predefined then ""
                   else !current.cmd_browse])
      !current.cmd_browse
  in
  let doc_url =
    let predefined = [
      "file://"^(List.fold_left Filename.concat (Coq_config.docdir) ["html";"refman";""]);
      Coq_config.wwwrefman;
      use_default_doc_url
    ] in
    combo
      "Manual URL"
      ~f:(fun s -> !current.doc_url <- s)
      ~new_allowed: true
      (predefined@[if List.mem !current.doc_url predefined then ""
                   else !current.doc_url])
      !current.doc_url in
  let library_url =
    let predefined = [
      "file://"^(List.fold_left Filename.concat (Coq_config.docdir) ["html";"stdlib";""]);
      Coq_config.wwwstdlib
    ] in
    combo
      "Library URL"
      ~f:(fun s -> !current.library_url <- s)
      ~new_allowed: true
      (predefined@[if List.mem !current.library_url predefined then ""
                   else !current.library_url])
      !current.library_url
  in
  let automatic_tactics =
    strings
      ~f:(fun l -> !current.automatic_tactics <- l)
      ~add:(fun () -> ["<edit me>"])
      "Wizard tactics to try in order"
      !current.automatic_tactics

  in

  let contextual_menus_on_goal =
    bool
      ~f:(fun s ->
	    !current.contextual_menus_on_goal <- s;
	    !contextual_menus_on_goal s)
      "Contextual menus on goal" !current.contextual_menus_on_goal
  in

  let misc = [contextual_menus_on_goal;auto_complete;stop_before;lax_syntax;
              vertical_tabs;opposite_tabs] in

(* ATTENTION !!!!! L'onglet Fonts doit etre en premier pour eviter un bug !!!!
   (shame on Benjamin) *)
  let cmds =
    [Section("Fonts", Some `SELECT_FONT,
	     [config_font]);
     Section("Colors", Some `SELECT_COLOR, [config_color]);
     Section("Files", Some `DIRECTORY,
	     [global_auto_revert;global_auto_revert_delay;
	      auto_save; auto_save_delay; (* auto_save_name*)
	      encodings;
	     ]);
     Section("Project", Some (`STOCK "gtk-page-setup"),
	     [project_file_name;read_project;
	     ]);
(*
     Section("Appearance",
	     config_appearance);
*)
     Section("Externals", None,
	     [cmd_coqc;cmd_make;cmd_coqmakefile; cmd_coqdoc; cmd_print;
	      cmd_editor;
	      cmd_browse;doc_url;library_url]);
     Section("Tactics Wizard", None,
	     [automatic_tactics]);
     Section("Shortcuts", Some `PREFERENCES,
	     [modifiers_valid; modifier_for_tactics;
	      modifier_for_templates; modifier_for_display; modifier_for_navigation]);
     Section("Misc", Some `ADD,
	     misc)]
  in
(*
  Format.printf "before edit: current.text_font = %s@." (Pango.Font.to_string !current.text_font);
*)
  let x = edit ~apply ~width:640 "Customizations" cmds in
(*
  Format.printf "after edit: current.text_font = %s@." (Pango.Font.to_string !current.text_font);
*)
  match x with
    | Return_apply | Return_ok -> save_pref ()
    | Return_cancel -> ()
