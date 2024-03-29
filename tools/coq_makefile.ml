(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2010     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(* cr�er un Makefile pour un d�veloppement Coq automatiquement *)

let output_channel = ref stdout
let makefile_name = ref "Makefile"
let make_name = ref ""

let some_vfile = ref false
let some_mlfile = ref false
let some_mlifile = ref false
let some_ml4file = ref false
let some_mllibfile = ref false
let some_mlpackfile = ref false

let print x = output_string !output_channel x
let printf x = Printf.fprintf !output_channel x

let rec print_list sep = function
  | [ x ] -> print x
  | x :: l -> print x; print sep; print_list sep l
  | [] -> ()

let list_iter_i f =
  let rec aux i = function [] -> () | a::l -> f i a; aux (i+1) l in aux 1

let section s =
  let l = String.length s in
  let sep = String.make (l+5) '#'
  and sep2 = String.make (l+5) ' ' in
  String.set sep (l+4) '\n';
  String.set sep2 0 '#';
  String.set sep2 (l+3) '#';
  String.set sep2 (l+4) '\n';
  print sep;
  print sep2;
  print "# "; print s; print " #\n";
  print sep2;
  print sep;
  print "\n"

let usage () =
  output_string stderr "Usage summary:

coq_makefile [subdirectory] .... [file.v] ... [file.ml[i4]?] ... [file.mllib]
  ... [-custom command dependencies file] ... [-I dir] ... [-R physicalpath
  logicalpath] ... [VARIABLE = value] ...  [-arg opt] ... [-opt|-byte]
  [-no-install] [-f file] [-o file] [-h] [--help]

[file.v]: Coq file to be compiled
[file.ml[i4]?]: Objective Caml file to be compiled
[file.mllib]: ocamlbuild file that describes a Objective Caml library
[subdirectory] : subdirectory that should be \"made\" and has a
  Makefile itself to do so.
[-custom command dependencies file]: add target \"file\" with command
  \"command\" and dependencies \"dependencies\"
[-I dir]: look for Objective Caml dependencies in \"dir\"
[-R physicalpath logicalpath]: look for Coq dependencies resursively
  starting from \"physicalpath\". The logical path associated to the
  physical path is \"logicalpath\".
[VARIABLE = value]: Add the variable definition \"VARIABLE=value\"
[-byte]: compile with byte-code version of coq
[-opt]: compile with native-code version of coq
[-arg opt]: send option \"opt\" to coqc
[-install opt]: where opt is \"user\" to force install into user directory,
  \"none\" to build a makefile with no install target or
  \"global\" to force install in $COQLIB directory
[-f file]: take the contents of file as arguments
[-o file]: output should go in file file
	Output file outside the current directory is forbidden.
[-h]: print this usage summary
[--help]: equivalent to [-h]\n";
  exit 1

let is_genrule r =
    let genrule = Str.regexp("%") in
      Str.string_match genrule r 0

let string_prefix a b =
  let rec aux i = try if a.[i] = b.[i] then aux (i+1) else i with |Invalid_argument _ -> i in
    String.sub a 0 (aux 0)

let is_prefix dir1 dir2 =
  let l1 = String.length dir1 in
  let l2 = String.length dir2 in
    dir1 = dir2 or (l1 < l2 & String.sub dir2 0 l1 = dir1 & dir2.[l1] = '/')

let physical_dir_of_logical_dir ldir =
  let le = String.length ldir - 1 in
  let pdir = if ldir.[le] = '.' then String.sub ldir 0 (le - 1) else String.copy ldir in
  for i = 0 to le - 1 do
    if pdir.[i] = '.' then pdir.[i] <- '/';
  done;
  pdir

let standard opt =
  print "byte:\n";
  print "\t$(MAKE) all \"OPT:=-byte\"\n\n";
  print "opt:\n";
  if not opt then print "\t@echo \"WARNING: opt is disabled\"\n";
  print "\t$(MAKE) all \"OPT:="; print (if opt then "-opt" else "-byte");
  print "\"\n\n"

let classify_files_by_root var files (inc_i,inc_r) =
  if not (List.exists (fun (pdir,_,_) -> pdir = ".") inc_r) then
    begin
      let absdir_of_files = List.rev_map
	(fun x -> Minilib.canonical_path_name (Filename.dirname x))
	files in
	(* files in scope of a -I option (assuming they are no overlapping) *)
      let has_inc_i = List.exists (fun (_,a) -> List.mem a absdir_of_files) inc_i in
	if has_inc_i then
	  begin
	    printf "%sINC=" var;
	    List.iter (fun (pdir,absdir) ->
			 if List.mem absdir absdir_of_files
			 then printf
			   "$(filter $(wildcard %s/*),$(%s)) "
			   pdir var
		      ) inc_i;
	    printf "\n";
	  end;
      (* Files in the scope of a -R option (assuming they are disjoint) *)
	list_iter_i (fun i (pdir,ldir,abspdir) ->
		       if List.exists (is_prefix abspdir) absdir_of_files then
			 printf "%s%d=$(patsubst %s/%%,%%,$(filter %s/%%,$(%s)))\n"
			   var i pdir pdir var)
	  inc_r;
    end

let install_include_by_root files_var files (inc_i,inc_r) =
  try
    (* All files caught by a -R . option (assuming it is the only one) *)
    let ldir = match inc_r with
      |[(".",t,_)] -> t
      |l -> let out = List.assoc "." (List.map (fun (p,l,_) -> (p,l)) inc_r) in
	 let () = prerr_string "Warning: install rule assumes that -R . _ is the only -R option" in
	   out in
    let pdir = physical_dir_of_logical_dir ldir in
      printf "\tfor i in $(%s); do \\\n" files_var;
      printf "\t install -d `dirname $(DSTROOT)$(COQLIBINSTALL)/%s/$$i`; \\\n" pdir;
      printf "\t install -m 0644 $$i $(DSTROOT)$(COQLIBINSTALL)/%s/$$i; \\\n" pdir;
      printf "\tdone\n"
  with Not_found ->
    let absdir_of_files = List.rev_map
      (fun x -> Minilib.canonical_path_name (Filename.dirname x))
      files in
    let has_inc_i_files =
      List.exists (fun (_,a) -> List.mem a absdir_of_files) inc_i in
    let install_inc_i d =
      printf "\tinstall -d $(DSTROOT)$(COQLIBINSTALL)/%s; \\\n" d;
      printf "\tfor i in $(%sINC); do \\\n" files_var;
      printf "\t install -m 0644 $$i $(DSTROOT)$(COQLIBINSTALL)/%s/`basename $$i`; \\\n" d;
      printf "\tdone\n"
    in
      if inc_r = [] then
	if has_inc_i_files then
	  begin
	    (* Files in the scope of a -I option *)
	    install_inc_i "$(INSTALLDEFAULTROOT)";
	  end else ()
      else
	(* Files in the scope of a -R option (assuming they are disjoint) *)
	list_iter_i (fun i (pdir,ldir,abspdir) ->
		       let has_inc_r_files = List.exists (is_prefix abspdir) absdir_of_files in
		       let pdir' = physical_dir_of_logical_dir ldir in
			 if has_inc_r_files then
			   begin
			     printf "\tcd %s; for i in $(%s%d); do \\\n" pdir files_var i;
			     printf "\t install -d `dirname $(DSTROOT)$(COQLIBINSTALL)/%s/$$i`; \\\n" pdir';
			     printf "\t install -m 0644 $$i $(DSTROOT)$(COQLIBINSTALL)/%s/$$i; \\\n" pdir';
			     printf "\tdone\n";
			   end;
			 if has_inc_i_files then install_inc_i pdir'
		    ) inc_r

let install_doc some_vfiles some_mlifiles (_,inc_r) =
  let install_one_kind kind dir =
    printf "\tinstall -d $(DSTROOT)$(COQDOCINSTALL)/%s/%s\n" dir kind;
    printf "\tfor i in %s/*; do \\\n" kind;
    printf "\t install -m 0644 $$i $(DSTROOT)$(COQDOCINSTALL)/%s/$$i;\\\n" dir;
    print "\tdone\n" in
    print "install-doc:\n";
    let () = match inc_r with
      |[] ->
	 if some_vfiles then install_one_kind "html" "$(INSTALLDEFAULTROOT)";
	  if some_mlifiles then install_one_kind "mlihtml" "$(INSTALLDEFAULTROOT)";
      |(_,lp,_)::q ->
	 let pr = List.fold_left (fun a (_,b,_) -> string_prefix a b) lp q in
	   if (pr <> "") &&
	     ((List.exists (fun(_,b,_) -> b = pr) inc_r) || pr.[String.length pr - 1] = '.')
	   then begin
	     let rt = physical_dir_of_logical_dir pr in
	       if some_vfiles then install_one_kind "html" rt;
	       if some_mlifiles then install_one_kind "mlihtml" rt;
	   end else begin
	     prerr_string "Warning: -R options don't have a correct common prefix,
 install-doc will put anything in $INSTALLDEFAULTROOT";
	   if some_vfiles then install_one_kind "html" "$(INSTALLDEFAULTROOT)";
	   if some_mlifiles then install_one_kind "mlihtml" "$(INSTALLDEFAULTROOT)";
	   end in
      print "\n"

let install (vfiles,(mlifiles,ml4files,mlfiles,mllibfiles,mlpackfiles),_,sds) inc = function
  |Project_file.NoInstall -> ()
  |is_install ->
    let () = if is_install = Project_file.UnspecInstall then
	print "userinstall:\n\t+$(MAKE) USERINSTALL=true install\n\n" in
  let not_empty = function |[] -> false |_::_ -> true in
  let cmofiles = mlpackfiles@mlfiles@ml4files in
  let cmifiles = mlifiles@cmofiles in
  let cmxsfiles = cmofiles@mllibfiles in
    if (not_empty cmxsfiles) then begin
      print "install-natdynlink:\n";
      install_include_by_root "CMXSFILES" cmxsfiles inc;
      print "\n";
    end;
    print "install:";
    if (not_empty cmxsfiles) then print "$(if ifeq '$(HASNATDYNLINK)' 'true',install-natdynlink)";
    print "\n";
    if not_empty vfiles then install_include_by_root "VOFILES" vfiles inc;
    if (not_empty cmofiles) then
      install_include_by_root "CMOFILES" cmofiles inc;
    if (not_empty cmifiles) then
      install_include_by_root "CMIFILES" cmifiles inc;
    if (not_empty mllibfiles) then
      install_include_by_root "CMAFILES" mllibfiles inc;
    List.iter
      (fun x ->
	 printf "\t(cd %s; $(MAKE) DSTROOT=$(DSTROOT) INSTALLDEFAULTROOT=$(INSTALLDEFAULTROOT)/%s install)\n" x x)
      sds;
    print "\n";
    install_doc (not_empty vfiles) (not_empty mlifiles) inc

let make_makefile sds =
  if !make_name <> "" then begin
    printf "%s: %s\n" !makefile_name !make_name;
    print "\tmv -f $@ $@.bak\n";
    print "\t$(COQBIN)coq_makefile -f $< -o $@\n\n";
    List.iter
      (fun x -> print "\t(cd "; print x; print " ; $(MAKE) Makefile)\n")
      sds;
    print "\n";
  end

let clean sds sps =
  print "clean:\n";
  if !some_mlfile || !some_mlifile || !some_ml4file || !some_mllibfile || !some_mlpackfile then begin
    print "\trm -f $(ALLCMOFILES) $(CMIFILES) $(CMAFILES)\n";
    print "\trm -f $(ALLCMOFILES:.cmo=.cmx) $(CMXAFILES) $(CMXSFILES) $(ALLCMOFILES:.cmo=.o) $(CMXAFILES:.cmxa=.a)\n";
    print "\trm -f $(addsuffix .d,$(MLFILES) $(MLIFILES) $(ML4FILES) $(MLLIBFILES) $(MLPACKFILES))\n";
  end;
  if !some_vfile then
    print "\trm -f $(VOFILES) $(VIFILES) $(GFILES) $(VFILES:.v=.v.d) $(VFILES:=.beautified) $(VFILES:=.old)\n";
  print "\trm -f all.ps all-gal.ps all.pdf all-gal.pdf all.glob $(VFILES:.v=.glob) $(VFILES:.v=.tex) $(VFILES:.v=.g.tex) all-mli.tex\n";
  print "\t- rm -rf html mlihtml\n";
  List.iter
    (fun (file,_,_) ->
       if not (is_genrule file) then
	 (print "\t- rm -rf "; print file; print "\n"))
    sps;
  List.iter
    (fun x -> print "\t(cd "; print x; print " ; $(MAKE) clean)\n")
    sds;
  print "\n";
  print "archclean:\n";
  print "\trm -f *.cmx *.o\n";
  List.iter
    (fun x -> print "\t(cd "; print x; print " ; $(MAKE) archclean)\n")
    sds;
  print "\n";
  print "printenv:\n\t@$(COQBIN)coqtop -config\n";
  print "\t@echo CAMLC =\t$(CAMLC)\n\t@echo CAMLOPTC =\t$(CAMLOPTC)\n\t@echo PP =\t$(PP)\n\t@echo COQFLAGS =\t$(COQFLAGS)\n";
  print "\t@echo COQLIBINSTALL =\t$(COQLIBINSTALL)\n\t@echo COQDOCINSTALL =\t$(COQDOCINSTALL)\n\n"

let header_includes () = ()

let implicit () =
    section "Implicit rules.";
  let mli_rules () =
    print "%.cmi: %.mli\n\t$(CAMLC) $(ZDEBUG) $(ZFLAGS) $<\n\n";
    print "%.mli.d: %.mli\n";
    print "\t$(OCAMLDEP) -slash $(OCAMLLIBS) \"$<\" > \"$@\" || ( RV=$$?; rm -f \"$@\"; exit $${RV} )\n\n" in
  let ml4_rules () =
    print "%.cmo: %.ml4\n\t$(CAMLC) $(ZDEBUG) $(ZFLAGS) $(PP) -impl $<\n\n";
    print "%.cmx: %.ml4\n\t$(CAMLOPTC) $(ZDEBUG) $(ZFLAGS) $(PP) -impl $<\n\n";
    print "%.ml4.d: %.ml4\n";
    print "\t$(OCAMLDEP) -slash $(OCAMLLIBS) $(PP) -impl \"$<\" > \"$@\" || ( RV=$$?; rm -f \"$@\"; exit $${RV} )\n\n" in
  let ml_rules () =
    print "%.cmo: %.ml\n\t$(CAMLC) $(ZDEBUG) $(ZFLAGS) $<\n\n";
    print "%.cmx: %.ml\n\t$(CAMLOPTC) $(ZDEBUG) $(ZFLAGS) $<\n\n";
    print "%.ml.d: %.ml\n";
    print "\t$(OCAMLDEP) -slash $(OCAMLLIBS) \"$<\" > \"$@\" || ( RV=$$?; rm -f \"$@\"; exit $${RV} )\n\n" in
  let cmxs_rules () =
    print "%.cmxs: %.cmx\n\t$(CAMLOPTLINK) $(ZDEBUG) $(ZFLAGS) -shared -o $@ $<\n\n" in
  let mllib_rules () =
    print "%.cma: | %.mllib\n\t$(CAMLLINK) $(ZDEBUG) $(ZFLAGS) -a -o $@ $^\n\n";
    print "%.cmxa: | %.mllib\n\t$(CAMLOPTLINK) $(ZDEBUG) $(ZFLAGS) -a -o $@ $^\n\n";
    print "%.cmxs: %.cmxa\n\t$(CAMLOPTLINK) $(ZDEBUG) $(ZFLAGS) -linkall -shared -o $@ $<\n\n";
    print "%.mllib.d: %.mllib\n";
    print "\t$(COQDEP) -slash $(COQLIBS) -c \"$<\" > \"$@\" || ( RV=$$?; rm -f \"$@\"; exit $${RV} )\n\n" in
  let mlpack_rules () =
    print "%.cmo: | %.mlpack\n\t$(CAMLLINK) $(ZDEBUG) $(ZFLAGS) -pack -o $@ $^\n\n";
    print "%.cmx: | %.mlpack\n\t$(CAMLOPTLINK) $(ZDEBUG) $(ZFLAGS) -pack -o $@ $^\n\n";
    print "%.mlpack.d: %.mlpack\n";
    print "\t$(COQDEP) -slash $(COQLIBS) -c \"$<\" > \"$@\" || ( RV=$$?; rm -f \"$@\"; exit $${RV} )\n\n";
in
  let v_rules () =
    print "%.vo %.glob: %.v\n\t$(COQC) $(COQDEBUG) $(COQFLAGS) $*\n\n";
    print "%.vi: %.v\n\t$(COQC) -i $(COQDEBUG) $(COQFLAGS) $*\n\n";
    print "%.g: %.v\n\t$(GALLINA) $<\n\n";
    print "%.tex: %.v\n\t$(COQDOC) $(COQDOCFLAGS) -latex $< -o $@\n\n";
    print "%.html: %.v %.glob\n\t$(COQDOC) $(COQDOCFLAGS) -html $< -o $@\n\n";
    print "%.g.tex: %.v\n\t$(COQDOC) $(COQDOCFLAGS) -latex -g $< -o $@\n\n";
    print "%.g.html: %.v %.glob\n\t$(COQDOC)$(COQDOCFLAGS)  -html -g $< -o $@\n\n";
    print "%.v.d: %.v\n";
    print "\t$(COQDEP) -slash $(COQLIBS) \"$<\" > \"$@\" || ( RV=$$?; rm -f \"$@\"; exit $${RV} )\n\n";
    print "%.v.beautified:\n\t$(COQC) $(COQDEBUG) $(COQFLAGS) -beautify $*\n\n"
  in
    if !some_mlifile then mli_rules ();
    if !some_ml4file then ml4_rules ();
    if !some_mlfile then ml_rules ();
    if !some_mlfile || !some_ml4file then cmxs_rules ();
    if !some_mllibfile then mllib_rules ();
    if !some_mlpackfile then mlpack_rules ();
    if !some_vfile then v_rules ()

let variables is_install opt (args,defs) =
  let var_aux (v,def) = print v; print "="; print def; print "\n" in
    section "Variables definitions.";
    List.iter var_aux defs;
    print "\n";
    if not opt then
      print "override OPT:=-byte\n"
    else
      print "OPT?=\n";
    begin
      match args with
	|[] -> ()
	|h::t -> print "OTHERFLAGS=";
	  print h;
	  List.iter (fun s -> print " ";print s) t;
	  print "\n";
    end;
    (* Coq executables and relative variables *)
    if !some_vfile || !some_mlpackfile || !some_mllibfile then
      print "COQDEP?=$(COQBIN)coqdep -c\n";
    if !some_vfile then begin
    print "COQFLAGS?=-q $(OPT) $(COQLIBS) $(OTHERFLAGS) $(COQ_XML)\n";
    print "COQCHKFLAGS?=-silent -o\n";
    print "COQDOCFLAGS?=-interpolate -utf8\n";
    print "COQC?=$(COQBIN)coqc\n";
    print "GALLINA?=$(COQBIN)gallina\n";
    print "COQDOC?=$(COQBIN)coqdoc\n";
    print "COQCHK?=$(COQBIN)coqchk\n\n";
    end;
    (* Caml executables and relative variables *)
    if !some_ml4file || !some_mlfile || !some_mlifile then begin
    print "COQSRCLIBS?=-I $(COQLIB)kernel -I $(COQLIB)lib \\
  -I $(COQLIB)library -I $(COQLIB)parsing \\
  -I $(COQLIB)pretyping -I $(COQLIB)interp \\
  -I $(COQLIB)proofs -I $(COQLIB)tactics \\
  -I $(COQLIB)toplevel";
    List.iter (fun c -> print " \\
  -I $(COQLIB)plugins/"; print c) Coq_config.plugins_dirs; print "\n";
    print "ZFLAGS=$(OCAMLLIBS) $(COQSRCLIBS) -I $(CAMLP4LIB)\n\n";
    print "CAMLC?=$(OCAMLC) -c -rectypes\n";
    print "CAMLOPTC?=$(OCAMLOPT) -c -rectypes\n";
    print "CAMLLINK?=$(OCAMLC) -rectypes\n";
    print "CAMLOPTLINK?=$(OCAMLOPT) -rectypes\n";
    print "GRAMMARS?=grammar.cma\n";
    print "CAMLP4EXTEND?=pa_extend.cmo pa_macro.cmo q_MLast.cmo\n";
    print "CAMLP4OPTIONS?=-loc loc\n";
    print "PP?=-pp \"$(CAMLP4BIN)$(CAMLP4)o -I $(CAMLLIB) -I . $(COQSRCLIBS) $(CAMLP4EXTEND) $(GRAMMARS) $(CAMLP4OPTIONS) -impl\"\n\n";
    end;
    match is_install with
      | Project_file.NoInstall -> ()
      | Project_file.UnspecInstall ->
        section "Install Paths.";
	print "ifdef USERINSTALL\n";
        print "XDG_DATA_HOME?=$(HOME)/.local/share\n";
        print "COQLIBINSTALL=$(XDG_DATA_HOME)/coq\n";
        print "COQDOCINSTALL=$(XDG_DATA_HOME)/doc/coq\n";
	print "else\n";
        print "COQLIBINSTALL=${COQLIB}user-contrib\n";
        print "COQDOCINSTALL=${DOCDIR}user-contrib\n";
	print "endif\n\n"
      | Project_file.TraditionalInstall ->
          section "Install Paths.";
          print "COQLIBINSTALL=${COQLIB}user-contrib\n";
          print "COQDOCINSTALL=${DOCDIR}user-contrib\n";
          print "\n"
      | Project_file.UserInstall ->
          section "Install Paths.";
          print "XDG_DATA_HOME?=$(HOME)/.local/share\n";
          print "COQLIBINSTALL=$(XDG_DATA_HOME)/coq\n";
          print "COQDOCINSTALL=$(XDG_DATA_HOME)/doc/coq\n";
          print "\n"

let parameters () =
  print ".DEFAULT_GOAL := all\n\n# \n";
  print "# This Makefile may take arguments passed as environment variables:\n";
  print "# COQBIN to specify the directory where Coq binaries resides;\n";
  print "# ZDEBUG/COQDEBUG to specify debug flags for ocamlc&ocamlopt/coqc;\n";
  print "# DSTROOT to specify a prefix to install path.\n\n";
  print "# Here is a hack to make $(eval $(shell works:\n";
  print "define donewline\n\n\nendef\n";
  print "includecmdwithout@ = $(eval $(subst @,$(donewline),$(shell { $(1) | tr '\\n' '@'; })))\n";
  print "$(call includecmdwithout@,$(COQBIN)coqtop -config)\n\n"

let include_dirs (inc_i,inc_r) =
  let parse_includes l = List.map (fun (x,_) -> "-I " ^ x) l in
  let parse_rec_includes l =
    List.map (fun (p,l,_) ->
      let l' = if l = "" then "\"\"" else l in "-R " ^ p ^ " " ^ l')
      l in
  let inc_i' = List.filter (fun (_,i) -> not (List.exists (fun (_,_,i') -> is_prefix i' i) inc_r)) inc_i in
  let str_i = parse_includes inc_i in
  let str_i' = parse_includes inc_i' in
  let str_r = parse_rec_includes inc_r in
    section "Libraries definitions.";
    if !some_ml4file || !some_mlfile || !some_mlifile then begin
      print "OCAMLLIBS?="; print_list "\\\n  " str_i; print "\n";
    end;
    if !some_vfile then begin
      print "COQLIBS?="; print_list "\\\n  " str_i'; print " "; print_list "\\\n  " str_r; print "\n";
      print "COQDOCLIBS?=";   print_list "\\\n  " str_r; print "\n\n";
    end

let custom sps =
  let pr_path (file,dependencies,com) =
    print file; print ": "; print dependencies; print "\n";
    if com <> "" then (print "\t"; print com); print "\n\n"
  in
    if sps <> [] then section "Custom targets.";
    List.iter pr_path sps

let subdirs sds =
  let pr_subdir s =
    print s; print ":\n\tcd "; print s; print " ; $(MAKE) all\n\n"
  in
    if sds <> [] then section "Subdirectories.";
    List.iter pr_subdir sds

let forpacks l =
  let () = if l <> [] then section "Ad-hoc implicit rules for mlpack." in
  List.iter (fun it ->
    let h = Filename.chop_extension it in
    printf "$(addsuffix .cmx,$(filter $(basename $(MLFILES)),$(%s_MLPACK_DEPENDENCIES))): %%.cmx: %%.ml\n" h;
    printf "\t$(CAMLOPTC) $(ZDEBUG) $(ZFLAGS) -for-pack %s $<\n\n" (String.capitalize (Filename.basename h));
    printf "$(addsuffix .cmx,$(filter $(basename $(ML4FILES)),$(%s_MLPACK_DEPENDENCIES))): %%.cmx: %%.ml4\n" h;
    printf "\t$(CAMLOPTC) $(ZDEBUG) $(ZFLAGS) -for-pack %s $(PP) -impl $<\n\n" (String.capitalize (Filename.basename h))
  ) l

let main_targets vfiles (mlifiles,ml4files,mlfiles,mllibfiles,mlpackfiles) other_targets inc =
  let decl_var var = function
    |[] -> ()
    |l ->
      printf "%s:=" var; print_list "\\\n  " l; print "\n";
      printf "\n-include $(addsuffix .d,$(%s))\n.SECONDARY: $(addsuffix .d,$(%s))\n\n" var var
  in
  section "Files dispatching.";
  decl_var "VFILES" vfiles;
  begin match vfiles with
    |[] -> ()
    |l ->
      print "VOFILES:=$(VFILES:.v=.vo)\n";
      classify_files_by_root "VOFILES" l inc;
      print "GLOBFILES:=$(VFILES:.v=.glob)\n";
      print "VIFILES:=$(VFILES:.v=.vi)\n";
      print "GFILES:=$(VFILES:.v=.g)\n";
      print "HTMLFILES:=$(VFILES:.v=.html)\n";
      print "GHTMLFILES:=$(VFILES:.v=.g.html)\n"
  end;
  decl_var "ML4FILES" ml4files;
  decl_var "MLFILES" mlfiles;
  decl_var "MLPACKFILES" mlpackfiles;
  decl_var "MLLIBFILES" mllibfiles;
  decl_var "MLIFILES" mlifiles;
  let mlsfiles = match ml4files,mlfiles,mlpackfiles with
    |[],[],[] -> []
    |[],[],_ -> Printf.eprintf "Mlpack cannot work without ml[4]?"; []
    |[],ml,[] ->
      print "ALLCMOFILES:=$(MLFILES:.ml=.cmo)\n";
      ml
    |ml4,[],[] ->
      print "ALLCMOFILES:=$(ML4FILES:.ml4=.cmo)\n";
      ml4
    |ml4,ml,[] ->
      print "ALLCMOFILES:=$(ML4FILES:.ml4=.cmo) $(MLFILES:.ml=.cmo)\n";
      List.rev_append ml ml4
    |[],ml,mlpack ->
      print "ALLCMOFILES:=$(MLFILES:.ml=.cmo) $(MLPACKFILES:.mlpack=.cmo)\n";
      List.rev_append mlpack ml
    |ml4,[],mlpack ->
      print "ALLCMOFILES:=$(ML4FILES:.ml4=.cmo) $(MLPACKFILES:.mlpack=.cmo)\n";
      List.rev_append mlpack ml4
    |ml4,ml,mlpack ->
      print "ALLCMOFILES:=$(ML4FILES:.ml4=.cmo) $(MLFILES:.ml=.cmo) $(MLPACKFILES:.mlpack=.cmo)\n";
      List.rev_append mlpack (List.rev_append ml ml4) in
  begin match mlsfiles with
    |[] -> ()
    |l ->
  print "CMOFILES=$(filter-out $(addsuffix .cmo,$(foreach lib,$(MLLIBFILES:.mllib=_MLLIB_DEPENDENCIES) $(MLPACKFILES:.mlpack=_MLPACK_DEPENDENCIES),$($(lib)))),$(ALLCMOFILES))\n";
      classify_files_by_root "CMOFILES" l inc;
      print "CMXFILES=$(CMOFILES:.cmo=.cmx)\n";
      print "OFILES=$(CMXFILES:.cmx=.o)\n";
  end;
  begin match mllibfiles with
    |[] -> ()
    |l ->
      print "CMAFILES:=$(MLLIBFILES:.mllib=.cma)\n";
	classify_files_by_root "CMAFILES" l inc;
      print "CMXAFILES:=$(CMAFILES:.cma=.cmxa)\n";
  end;
  begin match mlifiles,mlsfiles with
    |[],[] -> ()
    |l,[] ->
       print "CMIFILES:=$(MLIFILES:.mli=.cmi)\n";
	classify_files_by_root "CMIFILES" l inc;
    |[],l ->
      print "CMIFILES=$(ALLCMOFILES:.cmo=.cmi)\n";
      classify_files_by_root "CMIFILES" l inc;
    |l1,l2 ->
      print "CMIFILES=$(sort $(ALLCMOFILES:.cmo=.cmi) $(MLIFILES:.mli=.cmi))\n";
      classify_files_by_root "CMIFILES" (l1@l2) inc;
  end;
  begin match mllibfiles,mlsfiles with
    |[],[] -> ()
    |l,[] ->
      print "CMXSFILES:=$(CMXAFILES:.cmxa=.cmxs)\n";
      classify_files_by_root "CMXSFILES" l inc;
    |[],l ->
      print "CMXSFILES=$(CMXFILES:.cmx=.cmxs)\n";
      classify_files_by_root "CMXSFILES" l inc;
    |l1,l2 ->
      print "CMXSFILES=$(CMXFILES:.cmx=.cmxs) $(CMXAFILES:.cmxa=.cmxs)\n";
      classify_files_by_root "CMXSFILES" (l1@l2) inc;
  end;
  print "\n";
  section "Definition of the toplevel targets.";
  print "all: ";
  if !some_vfile then print "$(VOFILES) ";
  if !some_mlfile || !some_ml4file || !some_mlpackfile then print "$(CMOFILES) ";
  if !some_mllibfile then print "$(CMAFILES) ";
  if !some_mlfile || !some_ml4file || !some_mllibfile || !some_mlpackfile
  then print "$(if ifeq '$(HASNATDYNLINK)' 'true',$(CMXSFILES)) ";
  print_list "\\\n  " other_targets; print "\n\n";
  if !some_mlifile then
    begin
      print "mlihtml: $(MLIFILES:.mli=.cmi)\n";
      print "\t mkdir $@ || rm -rf $@/*\n";
      print "\t$(OCAMLDOC) -html -rectypes -d $@ -m A $(ZDEBUG) $(ZFLAGS) $(^:.cmi=.mli)\n\n";
      print "all-mli.tex: $(MLIFILES:.mli=.cmi)\n";
      print "\t$(OCAMLDOC) -latex -rectypes -o $@ -m A $(ZDEBUG) $(ZFLAGS) $(^:.cmi=.mli)\n\n";
    end;
  if !some_vfile then
    begin
      print "spec: $(VIFILES)\n\n";
      print "gallina: $(GFILES)\n\n";
      print "html: $(GLOBFILES) $(VFILES)\n";
      print "\t- mkdir -p html\n";
      print "\t$(COQDOC) -toc $(COQDOCFLAGS) -html $(COQDOCLIBS) -d html $(VFILES)\n\n";
      print "gallinahtml: $(GLOBFILES) $(VFILES)\n";
      print "\t- mkdir -p html\n";
      print "\t$(COQDOC) -toc $(COQDOCFLAGS) -html -g $(COQDOCLIBS) -d html $(VFILES)\n\n";
      print "all.ps: $(VFILES)\n";
      print "\t$(COQDOC) -toc $(COQDOCFLAGS) -ps $(COQDOCLIBS) -o $@ `$(COQDEP) -sort -suffix .v $^`\n\n";
      print "all-gal.ps: $(VFILES)\n";
      print "\t$(COQDOC) -toc $(COQDOCFLAGS) -ps -g $(COQDOCLIBS) -o $@ `$(COQDEP) -sort -suffix .v $^`\n\n";
      print "all.pdf: $(VFILES)\n";
      print "\t$(COQDOC) -toc $(COQDOCFLAGS) -pdf $(COQDOCLIBS) -o $@ `$(COQDEP) -sort -suffix .v $^`\n\n";
      print "all-gal.pdf: $(VFILES)\n";
      print "\t$(COQDOC) -toc $(COQDOCFLAGS) -pdf -g $(COQDOCLIBS) -o $@ `$(COQDEP) -sort -suffix .v $^`\n\n";
      print "validate: $(VOFILES)\n";
      print "\t$(COQCHK) $(COQCHKFLAGS) $(COQLIBS) $(notdir $(^:.vo=))\n\n";
      print "beautify: $(VFILES:=.beautified)\n";
      print "\tfor file in $^; do mv $${file%.beautified} $${file%beautified}old && mv $${file} $${file%.beautified}; done\n";
      print "\t@echo \'Do not do \"make clean\" until you are sure that everything went well!\'\n";
      print "\t@echo \'If there were a problem, execute \"for file in $$(find . -name \\*.v.old -print); do mv $${file} $${file%.old}; done\" in your shell/'\n\n"
    end

let all_target (vfiles, (_,_,_,_,mlpackfiles as mlfiles), sps, sds) inc =
  let special_targets = List.filter (fun (n,_,_) -> not (is_genrule n)) sps in
  let other_targets = List.map (function x,_,_ -> x) special_targets @ sds in
  main_targets vfiles mlfiles other_targets inc;
    print ".PHONY: ";
    print_list " "
      ("all" ::  "opt" :: "byte" :: "archclean" :: "clean" :: "install"
	:: "userinstall" :: "depend" :: "html" :: "validate" :: sds);
    print "\n\n";
    custom sps;
    subdirs sds;
    forpacks mlpackfiles

let banner () =
  print (Printf.sprintf
"#############################################################################
##  v      #                   The Coq Proof Assistant                     ##
## <O___,, #                INRIA - CNRS - LIX - LRI - PPS                 ##
##   \\VV/  #                                                               ##
##    //   #  Makefile automagically generated by coq_makefile V%s ##
#############################################################################

" (Coq_config.version ^ String.make (10 - String.length Coq_config.version) ' '))

let warning () =
  print "# WARNING\n#\n";
  print "# This Makefile has been automagically generated\n";
  print "# Edit at your own risks !\n";
  print "#\n# END OF WARNING\n\n"

let print_list l = List.iter (fun x -> print x; print " ") l

let command_line args =
  print "#\n# This Makefile was generated by the command line :\n";
  print "# coq_makefile ";
  print_list args;
  print "\n#\n\n"

let ensure_root_dir (v,(mli,ml4,ml,mllib,mlpack),_,_) ((i_inc,r_inc) as l) =
  let here = Sys.getcwd () in
  let not_tops =List.for_all (fun s -> s <> Filename.basename s) in
  if List.exists (fun (_,x) -> x = here) i_inc
    or List.exists (fun (_,_,x) -> is_prefix x here) r_inc
    or (not_tops v && not_tops mli && not_tops ml4 && not_tops ml
	&& not_tops mllib && not_tops mlpack) then
    l
  else
    ((".",here)::i_inc,r_inc)

let warn_install_at_root_directory
    (vfiles,(mlifiles,ml4files,mlfiles,mllibfiles,mlpackfiles),_,_) (inc_i,inc_r) =
  let inc_r_top = List.filter (fun (_,ldir,_) -> ldir = "") inc_r in
  let inc_top = List.map (fun (p,_,_) -> p) inc_r_top in
  let files = vfiles @ mlifiles @ ml4files @ mlfiles @ mllibfiles @ mlpackfiles in
  if inc_r = [] || List.exists (fun f -> List.mem (Filename.dirname f) inc_top) files
  then
    Printf.eprintf "Warning: install target will copy files at the first level of the coq contributions installation directory; option -R %sis recommended\n"
      (if inc_r_top = [] then "" else "with non trivial logical root ")

let check_overlapping_include (_,inc_r) =
  let pwd = Sys.getcwd () in
  let rec aux = function
    | [] -> ()
    | (pdir,_,abspdir)::l ->
	if not (is_prefix pwd abspdir) then
	  Printf.eprintf "Warning: in option -R, %s is not a subdirectory of the current directory\n" pdir;
	List.iter (fun (pdir',_,abspdir') ->
	  if is_prefix abspdir abspdir' or is_prefix abspdir' abspdir then
	    Printf.eprintf "Warning: in options -R, %s and %s overlap\n" pdir pdir') l;
  in aux inc_r

let do_makefile args =
  let has_file var = function
    |[] -> var := false
    |_::_ -> var := true in
  let (project_file,makefile,is_install,opt),l =
    try Project_file.process_cmd_line Filename.current_dir_name (None,None,Project_file.UnspecInstall,true) [] args
    with Project_file.Parsing_error -> usage () in
  let (v_f,(mli_f,ml4_f,ml_f,mllib_f,mlpack_f),sps,sds as targets), inc, defs =
    Project_file.split_arguments l in

  let () = match project_file with |None -> () |Some f -> make_name := f in
  let () = match makefile with
    |None -> ()
    |Some f -> makefile_name := f; output_channel := open_out f in
  has_file some_vfile v_f; has_file some_mlifile mli_f;
  has_file some_mlfile ml_f; has_file some_ml4file ml4_f;
  has_file some_mllibfile mllib_f; has_file some_mlpackfile mlpack_f;
  let check_dep f =
    if Filename.check_suffix f ".v" then some_vfile := true
    else if (Filename.check_suffix f ".mli") then some_mlifile := true
    else if (Filename.check_suffix f ".ml4") then some_ml4file := true
    else if (Filename.check_suffix f ".ml") then some_mlfile := true
    else if (Filename.check_suffix f ".mllib") then some_mllibfile := true
    else if (Filename.check_suffix f ".mlpack") then some_mlpackfile := true
  in
  List.iter (fun (_,dependencies,_) ->
    List.iter check_dep (Str.split (Str.regexp "[ \t]+") dependencies)) sps;

  let inc = ensure_root_dir targets inc in
  if is_install <> Project_file.NoInstall then warn_install_at_root_directory targets inc;
  check_overlapping_include inc;
  banner ();
  header_includes ();
  warning ();
  command_line args;
  parameters ();
  include_dirs inc;
  variables is_install opt defs;
  all_target targets inc;
  section "Special targets.";
  standard opt;
  install targets inc is_install;
  clean sds sps;
  make_makefile sds;
  implicit ();
  warning ();
  if not (makefile = None) then close_out !output_channel;
  exit 0

let main () =
  let args =
    if Array.length Sys.argv = 1 then usage ();
    List.tl (Array.to_list Sys.argv)
  in
    do_makefile args

let _ = Printexc.catch main ()
