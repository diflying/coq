(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2010     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

open Pcoq
open Pp
open Tactic
open Util
open Vernac_
open Topconstr
open Vernacexpr
open Prim
open Constr
open Tok

let thm_token = G_vernac.thm_token

(* Proof commands *)
GEXTEND Gram
  GLOBAL: command;

  opt_hintbases:
  [ [ -> []
    | ":"; l = LIST1 [id = IDENT -> id ] -> l ] ]
  ;
  command:
    [ [ IDENT "Goal"; c = lconstr -> VernacGoal c
      | IDENT "Proof" -> VernacProof (None,None)
      | IDENT "Proof" ; IDENT "Mode" ; mn = string -> VernacProofMode mn
      | IDENT "Proof"; "with"; ta = tactic; 
        l = OPT [ "using"; l = LIST0 identref  -> l ] ->
          VernacProof (Some ta, l)
      | IDENT "Proof"; "using"; l = LIST0 identref; 
        ta = OPT [ "with"; ta = tactic -> ta ] ->
          VernacProof (ta,Some l)
      | IDENT "Proof"; c = lconstr -> VernacExactProof c
      | IDENT "Abort" -> VernacAbort None
      | IDENT "Abort"; IDENT "All" -> VernacAbortAll
      | IDENT "Abort"; id = identref -> VernacAbort (Some id)
      | IDENT "Existential"; n = natural; c = constr_body ->
	  VernacSolveExistential (n,c)
      | IDENT "Admitted" -> VernacEndProof Admitted
      | IDENT "Qed" -> VernacEndProof (Proved (true,None))
      | IDENT "Save" -> VernacEndProof (Proved (true,None))
      | IDENT "Save"; tok = thm_token; id = identref ->
	  VernacEndProof (Proved (true,Some (id,Some tok)))
      | IDENT "Save"; id = identref ->
	  VernacEndProof (Proved (true,Some (id,None)))
      | IDENT "Defined" -> VernacEndProof (Proved (false,None))
      |	IDENT "Defined"; id=identref ->
	  VernacEndProof (Proved (false,Some (id,None)))
      | IDENT "Restart" -> VernacRestart
      | IDENT "Undo" -> VernacUndo 1
      | IDENT "Undo"; n = natural -> VernacUndo n
      | IDENT "Undo"; IDENT "To"; n = natural -> VernacUndoTo n
      | IDENT "Focus" -> VernacFocus None
      | IDENT "Focus"; n = natural -> VernacFocus (Some n)
      | IDENT "Unfocus" -> VernacUnfocus
      | IDENT "Unfocused" -> VernacUnfocused
      | IDENT "BeginSubproof" -> VernacSubproof None
      | IDENT "BeginSubproof"; n = natural -> VernacSubproof (Some n)
      | IDENT "EndSubproof" -> VernacEndSubproof
      | IDENT "Show" -> VernacShow (ShowGoal OpenSubgoals)
      | IDENT "Show"; n = natural -> VernacShow (ShowGoal (NthGoal n))
      | IDENT "Show"; IDENT "Goal"; n = string ->
          VernacShow (ShowGoal (GoalId n))
      | IDENT "Show"; IDENT "Implicit"; IDENT "Arguments"; n = OPT natural ->
	  VernacShow (ShowGoalImplicitly n)
      | IDENT "Show"; IDENT "Node" -> VernacShow ShowNode
      | IDENT "Show"; IDENT "Script" -> VernacShow ShowScript
      | IDENT "Show"; IDENT "Existentials" -> VernacShow ShowExistentials
      | IDENT "Show"; IDENT "Tree" -> VernacShow ShowTree
      | IDENT "Show"; IDENT "Conjectures" -> VernacShow ShowProofNames
      | IDENT "Show"; IDENT "Proof" -> VernacShow ShowProof
      | IDENT "Show"; IDENT "Intro" -> VernacShow (ShowIntros false)
      | IDENT "Show"; IDENT "Intros" -> VernacShow (ShowIntros true)
      | IDENT "Show"; IDENT "Match"; id = identref -> VernacShow (ShowMatch id)
      | IDENT "Show"; IDENT "Thesis" -> VernacShow ShowThesis
      | IDENT "Guarded" -> VernacCheckGuard
      (* Hints for Auto and EAuto *)
      | IDENT "Create"; IDENT "HintDb" ;
	  id = IDENT ; b = [ "discriminated" -> true | -> false ] ->
	    VernacCreateHintDb (use_module_locality (), id, b)
      | IDENT "Remove"; IDENT "Hints"; ids = LIST1 global; dbnames = opt_hintbases ->
	  VernacRemoveHints (use_module_locality (), dbnames, ids)
      | IDENT "Hint"; local = obsolete_locality; h = hint;
	  dbnames = opt_hintbases ->
	  VernacHints (enforce_module_locality local,dbnames, h)
      (* Declare "Resolve" explicitly so as to be able to later extend with
         "Resolve ->" and "Resolve <-" *)
      | IDENT "Hint"; IDENT "Resolve"; lc = LIST1 constr; n = OPT natural;
	  dbnames = opt_hintbases ->
	  VernacHints (use_module_locality (),dbnames,
	    HintsResolve (List.map (fun x -> (n, true, x)) lc))
      ] ];

  obsolete_locality:
    [ [ IDENT "Local" -> true | -> false ] ]
  ;
  hint:
    [ [ IDENT "Resolve"; lc = LIST1 constr; n = OPT natural ->
          HintsResolve (List.map (fun x -> (n, true, x)) lc)
      | IDENT "Immediate"; lc = LIST1 constr -> HintsImmediate lc
      | IDENT "Transparent"; lc = LIST1 global -> HintsTransparency (lc, true)
      | IDENT "Opaque"; lc = LIST1 global -> HintsTransparency (lc, false)
      | IDENT "Unfold"; lqid = LIST1 global -> HintsUnfold lqid
      | IDENT "Constructors"; lc = LIST1 global -> HintsConstructors lc
      | IDENT "Extern"; n = natural; c = OPT constr_pattern ; "=>";
          tac = tactic ->
	  HintsExtern (n,c,tac) ] ]
    ;
  constr_body:
    [ [ ":="; c = lconstr -> c
      | ":"; t = lconstr; ":="; c = lconstr -> CCast(loc,c, Glob_term.CastConv (Term.DEFAULTcast,t)) ] ]
  ;
END
