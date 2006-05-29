(* C states - to be expanded into C++ states *)

(* Michael Norrish *)

(* pro-forma *)
open HolKernel boolLib Parse bossLib BasicProvers
open boolSimps

(* Standard HOL ancestory theories *)
open arithmeticTheory pred_setTheory integerTheory
local open wordsTheory integer_wordTheory finite_mapTheory in end

(* C++ ancestor theories  *)
open typesTheory memoryTheory expressionsTheory statementsTheory

val _ = new_theory "states";
(* actually also the theory of declaration forms *)

(* information about a function, once declared.  A NONE value for the body
   indicates that the function has only been given a prototype  *)
val _ = Hol_datatype `fn_info = <| return_type : CPP_Type ;
                                   parameters  : (string # CPP_Type) list ;
                                   body        : CStmt option |>`;

(* Information about structures, once declared.
   Use the NONE value to indicate a struct has an incomplete declaration.
   Can't use the empty list for C++, as C++ allows declaration of empty
   structs/classes (unlike C)  (9 p1).

   NOTE, moreover that an empty C++ struct has non-zero size. (9 p3)
*)
val _ = type_abbrev ("str_info", ``:(string # CPP_Type) list option``)

(* BAD_ASSUMPTION: locmap maps from natural numbers;
                   should maybe map from pointer values *)
val _ = Hol_datatype
  `CState = <| allocmap : num -> bool ;
               fnmap    : string |-> fn_info ;
               gstrmap  : string |-> str_info ;
               gtypemap : string |-> CPP_Type ;
               gvarmap  : string |-> num ;
               initmap  : num -> bool ;
               locmap   : num -> byte ;
               strmap   : string |-> str_info ;
               typemap  : string |-> CPP_Type ;
               varmap   : string |-> num |>`;

(* function that updates memory with a value *)
val val2mem_def = Define`
  val2mem s (loc:num) v =
       s with locmap updated_by
                (\lmp x. if loc <= x /\ x < loc + LENGTH v then
                           EL (x - loc) v
                         else lmp x)
`;

(* function that extracts values from memory *)
val mem2val_def = Define`
  (mem2val s loc 0 = []) /\
  (mem2val s loc (SUC n) = s.locmap loc :: mem2val s (loc+1) n)
`;
val _ = export_rewrites ["mem2val_def"]

(* SANITY (trivial) *)
val mem2val_LENGTH = store_thm(
  "mem2val_LENGTH",
  --`!sz s n. LENGTH (mem2val s n sz) = sz`--,
  Induct THEN ASM_SIMP_TAC (srw_ss()) []);

val install_global_maps_def = Define`
  install_global_maps s =
         s with <| gvarmap := s.varmap ;
                   gstrmap := s.strmap;
                   gtypemap := s.typemap |>
`;

val _ = export_theory();