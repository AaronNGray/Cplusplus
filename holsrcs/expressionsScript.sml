(* C expressions - to be expanded into C++ expressions *)

(* Michael Norrish *)

(* pro-forma *)
open HolKernel boolLib Parse bossLib BasicProvers
open boolSimps

(* Standard HOL ancestory theories *)
open arithmeticTheory pred_setTheory integerTheory
local open wordsTheory integer_wordTheory finite_mapTheory in end

(* C++ ancestor theories  *)
open typesTheory memoryTheory

val _ = new_theory "expressions";

(* the standard binary operators *)
val c_binops = Hol_datatype
    `c_binops = CPlus | CMinus  | CLess  | CGreat | CLessE | CGreatE |
                CEq   | CTimes | CDiv   | CMod   | CNotEq`;

(* the standard unary operators *)
val c_unops = Hol_datatype
    `c_unops = CUnPlus | CUnMinus | CComp | CNot | CNullFunRef`;

(* expressions *)
val _ = type_abbrev ("CType", ``:CPP_Type``)
val _ = Hol_datatype
  `CExpr = Cnum of num
         | Cchar of num
         | Cnullptr of CType   (* BAD_ASSUMPTION: want to get rid of this *)
         | Var of string
         | COr of CExpr => CExpr
         | CAnd of CExpr => CExpr
         | CCond of CExpr => CExpr => CExpr
         | CApBinary of c_binops => CExpr => CExpr
         | CApUnary of c_unops => CExpr
         | Deref of CExpr
         | Addr of CExpr
         | Assign of c_binops option => CExpr => CExpr => (num -> num)
         | SVar of CExpr => string
         | FnApp of CExpr => CExpr list
         | CommaSep of CExpr => CExpr
         | Cast of CType => CExpr
         | PostInc of CExpr

         (* these are "fake expression constructors" *)
         | CAndOr_sqpt of CExpr
         | FnApp_sqpt of CExpr => CExpr list
         | LVal of num => CType
         | RValreq of CExpr
         | ECompVal of byte list => CType
         | UndefinedExpr `;

val rec_expr_P_def = Define`
    (rec_expr_P (Cnum i) = \P. P (Cnum i)) /\
    (rec_expr_P (Cchar c) = \P. P (Cchar c)) /\
    (rec_expr_P (Cnullptr t) = \P. P (Cnullptr t)) /\
    (rec_expr_P (Var n) = \P. P (Var n)) /\
    (rec_expr_P (COr e1 e2) =
      \P. P (COr e1 e2) /\ rec_expr_P e1 P /\ rec_expr_P e2 P) /\
    (rec_expr_P (CAnd e1 e2) =
      \P. P (CAnd e1 e2) /\ rec_expr_P e1 P /\ rec_expr_P e2 P) /\
    (rec_expr_P (CCond e1 e2 e3) =
      \P. P (CCond e1 e2 e3) /\ rec_expr_P e1 P /\ rec_expr_P e2 P /\
          rec_expr_P e3 P) /\
    (rec_expr_P (CApBinary f e1 e2) =
      \P. P (CApBinary f e1 e2) /\ rec_expr_P e1 P /\
          rec_expr_P e2 P) /\
    (rec_expr_P (CApUnary f' e) =
      \P. P (CApUnary f' e) /\ rec_expr_P e P) /\
    (rec_expr_P (Deref e) = \P. P (Deref e) /\ rec_expr_P e P) /\
    (rec_expr_P (Addr e) = \P. P (Addr e) /\ rec_expr_P e P) /\
    (rec_expr_P (Assign fo e1 e2 b) =
      \P. P (Assign fo e1 e2 b) /\ rec_expr_P e1 P /\ rec_expr_P e2 P) /\
    (rec_expr_P (SVar e fld) =
      \P. P (SVar e fld) /\ rec_expr_P e P) /\
    (rec_expr_P (FnApp e args) =
      \P. P (FnApp e args) /\ rec_expr_P e P /\ rec_exprl_P args P) /\
    (rec_expr_P (CommaSep e1 e2) =
      \P. P (CommaSep e1 e2) /\ rec_expr_P e1 P /\ rec_expr_P e2 P) /\
    (rec_expr_P (Cast t e) = \P. P (Cast t e) /\ rec_expr_P e P) /\
    (rec_expr_P (PostInc e) = \P. P (PostInc e) /\ rec_expr_P e P) /\
    (rec_expr_P (CAndOr_sqpt e) =
      \P. P (CAndOr_sqpt e) /\ rec_expr_P e P) /\
    (rec_expr_P (FnApp_sqpt e args) =
      \P. P (FnApp_sqpt e args) /\ rec_expr_P e P /\
          rec_exprl_P args P) /\
    (rec_expr_P (LVal a t) = \P. P (LVal a t)) /\
    (rec_expr_P (RValreq e) = \P. P (RValreq e) /\ rec_expr_P e P) /\
    (rec_expr_P (ECompVal v t) = \P. P (ECompVal v t)) /\
    (rec_expr_P UndefinedExpr = \P. P UndefinedExpr) /\
    (rec_exprl_P [] = \P. T) /\
    (rec_exprl_P (CONS e es) =
      \P. rec_expr_P e P /\ rec_exprl_P es P)`;
val rec_expr_P = save_thm("rec_expr_P", rec_expr_P_def);

open SingleStep
val rec_expr_simple = store_thm(
  "rec_expr_simple",
  (--`!P e. rec_expr_P e P ==> P e`--),
  REPEAT GEN_TAC THEN Cases_on `e` THEN
  SIMP_TAC (srw_ss()) [rec_expr_P]);

val rec_exprl_EVERY = store_thm(
  "rec_exprl_EVERY",
  (--`!el P. rec_exprl_P el P = EVERY (\e. rec_expr_P e P) el`--),
  INDUCT_THEN (listTheory.list_INDUCT) ASSUME_TAC THEN
  ASM_SIMP_TAC (srw_ss()) [rec_expr_P]);
val _ = export_rewrites ["rec_exprl_EVERY"]

val e_cases =
  (map (rhs o snd o strip_exists) o
   strip_disj o snd o strip_forall o concl)
  (theorem "CExpr_nchotomy")

val has_no_undefineds_def = Define`
  has_no_undefineds e = rec_expr_P e (\e. ~(e = UndefinedExpr))
`;

val e_thms =
    map
      (SIMP_RULE (srw_ss()) [GSYM has_no_undefineds_def] o
       GEN_ALL o
       SIMP_RULE (srw_ss()) [rec_expr_P] o
       GEN_ALL o
       C SPEC has_no_undefineds_def)
      e_cases
val has_no_undefineds = save_thm("has_no_undefineds", LIST_CONJ e_thms)
val _ = export_rewrites ["has_no_undefineds"]

val side_affecting_def = Define`
  (side_affecting (Assign f e1 e2 b) = T) /\
  (side_affecting (FnApp fdes args) = T) /\
  (side_affecting (FnApp_sqpt fdes args) = T) /\
  (side_affecting (PostInc e)    = T) /\
  (side_affecting allelse = F)
`;
val syn_pure_expr_def = Define`
  syn_pure_expr e = rec_expr_P e ($~ o side_affecting)
`;

val has_sqpt = Define`
  (has_sqpt (FnApp f args) = T) /\
  (has_sqpt (FnApp_sqpt f args) = T) /\
  (has_sqpt (CommaSep e1 e2) = T) /\
  (has_sqpt (CAnd e1 e2) = T) /\
  (has_sqpt (COr e1 e2) = T) /\
  (has_sqpt (CCond e1 e2 e3) = T) /\
  (has_sqpt allelse = F)
`;
val seqpt_free_def = Define`
  seqpt_free e = rec_expr_P e ($~ o has_sqpt)
`;

val _ = export_theory();