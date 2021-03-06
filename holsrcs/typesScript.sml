(* C++ Types - mainly derived from section 3.9 of the standard *)

(* Michael Norrish *)

open HolKernel boolLib Parse BasicProvers
open simpLib bossLib arithmeticTheory pred_setTheory boolSimps

local open stringTheory integerTheory in end;
open listTheory

val _ = new_theory "types";

val _ = Hol_datatype `basic_integral_type = Char | Short | Int | Long`;

val _ = Hol_datatype `

   (* a CPP_ID may denote a type or an object *)
   CPP_ID = IDConstant of bool => IDComp list => IDComp

   ;

   IDComp = IDTempCall of string => TemplateArg list
          | IDName of string

   ;

   TemplateArg = TType of CPP_Type
               | TTemp of CPP_ID
               | TVal of TemplateValueArg

   ;

   TemplateValueArg = TNum of int
                    | TObj of CPP_ID
                        (* string is name of suitable global (one that has
                           linkage etc).  It might be nested inside name-
                           spaces, or enclosing classes. *)
                    | TMPtr of CPP_ID => CPP_Type
                    | TVAVar of string (* => CPP_Type *)
                        (* can have a value (of the given type)
                           substituted for this *)


   ;

   CPP_Type =
     Void |
     BChar (* "Basic char" *) |
     Bool |
     (* Wchar_t |  - not clear if this is a distinct type, or just a synonym
                     for an existing type *)
     Unsigned of basic_integral_type |
     Signed of basic_integral_type |
     Class of CPP_ID  (* no variables inside! *)|
     Float |
     Double |
     LDouble |
     Ptr of CPP_Type |
     MPtr of CPP_ID => CPP_Type |
       (* member pointer *)
     Ref of CPP_Type |
     Array of CPP_Type => num |
     Function of CPP_Type => CPP_Type list |
     Const of CPP_Type |
     TypeID of CPP_ID
`;
val _ = export_rewrites [ "CPP_ID_size_def" ]

(* for backwards compatibility *)

val Base_def = Define`
  Base n = IDConstant F [] (IDName n)
`;

val sfld_basename_def = Define`
  (sfld_basename (IDName s) = s) /\
  (sfld_basename (IDTempCall s args) = s)
`;
val _ = overload_on ("sfld_string", ``sfld_basename``)
val _ = export_rewrites ["sfld_basename_def"]

val is_abs_id_def = Define`
  (is_abs_id (IDConstant b ns n) = b)
`;
val _ = export_rewrites ["is_abs_id_def"]

val IDtl_def = Define`
  IDtl (IDConstant b sfs sf) = sf
`;
val _ = export_rewrites ["IDtl_def"]

val dest_id_def = Define`
  dest_id (IDConstant b sfs sf) = (b,sfs,sf)
`
val _ = export_rewrites ["dest_id_def"]

val is_qualified_def = Define`
  is_qualified (IDConstant b sfs sf) = ~(sfs = [])
`;
val _ = export_rewrites ["is_qualified_def"]

val mk_member_def = Define`
  mk_member (IDConstant b sfs sf1) sf2 = IDConstant b (sfs ++ [sf1]) sf2
`;

val id_sfs_def = Define`
  id_sfs (IDConstant b sfs sf) = sfs ++ [sf]
`;
val _ = export_rewrites ["id_sfs_def"]

val is_var_type_def = Define`
  (is_var_type (TypeID cid) = T) /\
  (is_var_type _ = F)
`;

val dest_var_type_def = Define`
  (dest_var_type (TypeID cid) = cid)
`;

val typeid_def = Define`
  (typeid (TypeID cid) = SOME cid) /\
  (typeid _ = NONE)
`;
val _ = export_rewrites ["typeid_def"]

val IDhd_def = Define`
  (IDhd (IDConstant b [] sf) = sf) /\
  (IDhd (IDConstant b (h::t) sf) = h)
`;
val _ = export_rewrites ["IDhd_def"]

val dest_sfname_def = Define`
  (dest_sfname (IDName s) = s)
`;
val _ = export_rewrites ["dest_sfname_def"]


val ptrdiff_t = new_specification (
  "ptrdiff_t", ["ptrdiff_t"],
  CONV_RULE SKOLEM_CONV (prove(
    ``?t. t IN {Signed Char; Signed Short; Signed Int; Signed Long}``,
    SIMP_TAC (srw_ss()) [EXISTS_OR_THM])));

val const_type_def = Define`
  (const_type (Const ty) = T) /\
  (const_type _ = F)
`;

val strip_const_def = Define`
  (strip_const (Const ty) = strip_const ty) /\
  (strip_const ty = ty)
`;
val _ = export_rewrites ["strip_const_def"]

(* strip out all consts from a pointer chain *)
val strip_ptr_const_def = Define`
  (strip_ptr_const (Const ty) = strip_ptr_const ty) /\
  (strip_ptr_const (Ptr ty) = Ptr (strip_ptr_const ty)) /\
  (strip_ptr_const (MPtr cnm ty) = MPtr cnm (strip_ptr_const ty)) /\
  (strip_ptr_const ty = ty)
`;

val array_size_def = Define`
  (array_size (Array bt n) = n * array_size bt) /\
  (array_size ty = 1)
`;

val strip_array_def = Define`
  (strip_array (Array bt n) = strip_array bt) /\
  (strip_array t = t)
`;

(* protection types for fields *)
val _ = Hol_datatype`
  protection = Private | Public | Protected
`;

(* the boolean field indicates whether or not the field is static,
   true for static, false for non-static *)
val _ = Hol_datatype `
  class_member = ClassFld of bool => protection => CPP_Type
`;

(* 3.9.2 p1 "implicit" *)
val function_type_def = Define`
  (function_type (Function r a) = T) /\
  (function_type x = F)
`;
val _ = export_rewrites ["function_type_def"]

val dest_function_type_def = Define`
  dest_function_type (Function r a) = (r,a)
`;
val _ = export_rewrites ["dest_function_type_def"]

(* 3.9.2 p1 "implicit" *)
val ref_type_def = Define`
  (ref_type (Ref t0) = T) /\ (ref_type x = F)
`;
val _ = export_rewrites ["ref_type_def"]

(* 3.9.2 p1 "implicit" *)
val class_type_def = Define`
  (class_type (Class nm) = T) /\
  (class_type (Const ty) = class_type ty) /\
  (class_type x = F)
`;
val _ = export_rewrites ["class_type_def"]

val dest_class_def = Define`
  (dest_class (Class nm) = nm) /\
  (dest_class (Const ty) = dest_class ty)
`;
val _ = export_rewrites ["dest_class_def"]

(* 3.9 p9 *)
val object_type_def = Define`
  object_type t = ~function_type t /\ ~ref_type t /\ ~(t = Void)
`;

(* 3.9.1 p7 *)
val integral_type_def = Define`
  (integral_type (Signed i) = T) /\
  (integral_type (Unsigned i) = T) /\
  (integral_type BChar = T) /\
  (integral_type Bool = T) /\
  (integral_type (Const ty) = integral_type ty) /\
  (integral_type x = F)
`;
val _ = export_rewrites ["integral_type_def"]

(* 3.9.1 p8 *)
val floating_type_def = Define`
  (floating_type Float = T) /\
  (floating_type Double = T) /\
  (floating_type LDouble = T) /\
  (floating_type x = F)
`;
val _ = export_rewrites ["floating_type_def"]

(* 3.9.1 p8 *)
val arithmetic_type_def = Define`
  arithmetic_type t = integral_type t \/ floating_type t
`;

(* 3.9.2 p1 "implicit" *)
val pointer_type_def = Define `
  (pointer_type (Ptr t) = T) /\
  (pointer_type (Const ty) = pointer_type ty) /\
  (pointer_type x = F)
`;
val _ = export_rewrites ["pointer_type_def"]

val dest_ptr_def = Define`
  (dest_ptr (Ptr t) = t) /\
  (dest_ptr (Const t) = dest_ptr t)
`;
val _ = export_rewrites ["dest_ptr_def"]


(* 3.9.2 p1 "implicit" *)
val mpointer_type_def = Define`
  (mpointer_type (MPtr c t) = T) /\
  (mpointer_type (Const ty) = mpointer_type ty) /\
  (mpointer_type x = F)
`;
val _ = export_rewrites ["mpointer_type_def"]

(* 3.9 p10 *)
val scalar_type_def = Define`
  scalar_type t = pointer_type t \/ mpointer_type t \/
                  arithmetic_type t
`;

(* 3.9.2 p1 "implicit" *)
val array_type_def = Define`
  (array_type (Array t n) = T) /\
  (array_type x = F)
`;
val _ = export_rewrites ["array_type_def"]

(* numbers taken from C standard ISO/IEC 9899:1999 *)
val CHAR_BIT = new_specification ("CHAR_BIT", ["CHAR_BIT"],
  prove(--`?x. 8n <= x`--, PROVE_TAC [LESS_OR_EQ]));

local
  open integerTheory numSyntax
  val i = ==`:int`== and n = ==`:num`==
  val consts = [("CHAR",        "127",        "255",  8),
                ("SHRT",      "32767",      "65535", 16),
                ("INT",       "32767",      "65535", 16),
                ("LONG", "2147483647", "4294967295", 32)]
  val fromNum = mk_const("int_of_num", ``:num -> int``)
  fun c2n (s, sgn, usgn, uexp) = let
    val smax = intSyntax.term_of_int (Arbint.fromString sgn)
    val smin = --`~ ^smax`--
    val umax = intSyntax.term_of_int (Arbint.fromString usgn)
    val sminstr = (if s = "CHAR" then "S" else "")^s^"_MIN"
    val smaxstr = (if s = "CHAR" then "S" else "")^s^"_MAX"
    val umaxstr = "U"^s^"_MAX"
    val sminvar = Psyntax.mk_var(sminstr, i)
    val smaxvar = Psyntax.mk_var(smaxstr, i)
    val umaxvar = Psyntax.mk_var(umaxstr, i)
    val sminterm = --`(^sminvar = ~^smaxvar) \/
                      (^sminvar = ~^smaxvar - 1)`--
    val smaxterm =
      --`^smax <= ^smaxvar /\ (^smaxvar = (^umaxvar - 1) / 2)`--
    val umaxterm =
       --`^umax <= ^umaxvar /\ ?x. ^umaxvar = 2 ** x - 1`--
    in [(sminstr, sminvar, sminterm, smin),
        (smaxstr, smaxvar, smaxterm, smax),
        (umaxstr, umaxvar, umaxterm, umax)]
    end
  val humdinger = flatten (map c2n consts)
  val transterm = --`
    (LONG_MIN:int) <= INT_MIN /\ INT_MIN <= SHRT_MIN /\
    SHRT_MIN <= SCHAR_MIN /\
    SCHAR_MAX <= SHRT_MAX /\ SHRT_MAX <= INT_MAX /\
    INT_MAX <= (LONG_MAX:int)`--
  val uchar_max_term = ``UCHAR_MAX : int = 2 ** CHAR_BIT - 1``
  val vars = map #2 humdinger
  val answers = map #4 humdinger
  val body = list_mk_conj(uchar_max_term::transterm::(map #3 humdinger))
  val goal = list_mk_exists(vars, body)
  val eqsub = intLib.ARITH_PROVE ``((x:int - y <= z - y) = (x <= z)) /\
                                   ((x - y = z - y) = (x = z))``
  val useful = prove(
    ``(&(2 ** x) - 1i = (&(2 ** y) - 1 - 1) / 2) = (y = x + 1)``,
    EQ_TAC THENL [
      STRIP_TAC THEN Cases_on `y` THENL [
        FULL_SIMP_TAC (srw_ss()) [INT_EQ_SUB_RADD],
        FULL_SIMP_TAC (srw_ss()) [EXP] THEN
        `&(2 * 2 ** n) - 1i - 1 = 2 * (2 ** n - 1)`
           by (SIMP_TAC (srw_ss()) [INT_SUB_LDISTRIB] THEN
               intLib.ARITH_TAC) THEN
        FULL_SIMP_TAC (srw_ss()) [INT_DIV_LMUL, eqsub] THEN
        DECIDE_TAC
      ],
      SRW_TAC [][EXP_ADD] THEN
      `&(2 ** x * 2) - 1i - 1 = 2 * (2 ** x - 1)`
         by (SIMP_TAC (srw_ss()) [INT_SUB_LDISTRIB] THEN
             intLib.ARITH_TAC) THEN
      ASM_SIMP_TAC (srw_ss()) [INT_DIV_LMUL]
    ])


  val sat_thm = prove(
    goal,
    MAP_EVERY Q.EXISTS_TAC [`~(2 ** (CHAR_BIT - 1) - 1)`,
                            `2 ** (CHAR_BIT - 1) - 1`,
                            `2 ** CHAR_BIT - 1`,
                            `~(2 ** (CHAR_BIT + 7) - 1)`,
                            `(2 ** (CHAR_BIT + 7) - 1)`,
                            `2 ** (CHAR_BIT + 8) - 1`,
                            `~(2 ** (CHAR_BIT + 15) - 1)`,
                            `(2 ** (CHAR_BIT + 15) - 1)`,
                            `2 ** (CHAR_BIT + 16) - 1`,
                            `~(2 ** (CHAR_BIT + 31) - 1)`,
                            `(2 ** (CHAR_BIT + 31) - 1)`,
                            `2 ** (CHAR_BIT + 32) - 1`] THEN
    SIMP_TAC (srw_ss() ++ ARITH_ss) [eqsub, INT_LE_SUB_RADD,
                                     INT_LE_SUB_LADD] THEN
    SUBST_ALL_TAC (SYM (EVAL ``2n ** 7``)) THEN
    SUBST_ALL_TAC (SYM (EVAL ``2n ** 8``)) THEN
    SUBST_ALL_TAC (SYM (EVAL ``2n ** 15``)) THEN
    SUBST_ALL_TAC (SYM (EVAL ``2n ** 16``)) THEN
    SUBST_ALL_TAC (SYM (EVAL ``2n ** 31``)) THEN
    SUBST_ALL_TAC (SYM (EVAL ``2n ** 32``)) THEN
    SIMP_TAC (srw_ss()) [] THEN
    SIMP_TAC (srw_ss()) [useful] THEN ASSUME_TAC CHAR_BIT THEN
    intLib.ARITH_TAC)
  fun s2c str = {const_name = str, fixity = Prefix}
in
  val sizes = new_specification ("type_size_constants", map #1 humdinger, sat_thm)
end;

fun crossprod l1 l2 =
  let fun elprod e = map (fn e' => (e, e'))
  in
      flatten (map (fn f => f l2) (map elprod l1))
  end;
val int_types = ``Bool`` :: ``BChar`` :: map mk_comb
  (crossprod [--`Signed`--, --`Unsigned`--]
             [--`Char`--, --`Short`--, --`Int`--, --`Long`--])
(* \#line cholera-model.nw 242 *)
val sgn_min_def = Define`
  (sgn_min Char = SCHAR_MIN) /\
  (sgn_min Short = SHRT_MIN) /\
  (sgn_min Int = INT_MIN) /\
  (sgn_min Long = LONG_MIN)
`;
val _ = new_constant("BCHAR_IS_SIGNED", ``:bool``)

val type_min_def = Define `
  (type_min (Unsigned x) = 0) /\
  (type_min (Signed x) = sgn_min x) /\
  (type_min BChar = if BCHAR_IS_SIGNED then sgn_min Char else 0) /\
  (type_min Bool = 0)
`;

val type_min = save_thm(
  "type_min",
  LIST_CONJ (
    map (fn t => REWRITE_CONV [type_min_def, sgn_min_def]
                              (mk_comb(``type_min``, t)))
    int_types));
(* \#line cholera-model.nw 266 *)
val sgn_max_def = Define`
  (sgn_max Char = SCHAR_MAX) /\
  (sgn_max Short = SHRT_MAX) /\
  (sgn_max Int = INT_MAX) /\
  (sgn_max Long = LONG_MAX)
`;
val usgn_max_def = Define`
  (usgn_max Char = UCHAR_MAX) /\
  (usgn_max Short = USHRT_MAX) /\
  (usgn_max Int = UINT_MAX) /\
  (usgn_max Long = ULONG_MAX)
`;

val type_max_def = Define`
  (type_max (Unsigned x) = usgn_max x) /\
  (type_max (Signed x) = sgn_max x) /\
  (type_max Bool = 1) /\
  (type_max BChar = if BCHAR_IS_SIGNED then sgn_max Char else usgn_max Char)
`;

val type_max = save_thm(
  "type_max",
  LIST_CONJ (
    map (fn t => REWRITE_CONV [type_max_def, sgn_max_def, usgn_max_def]
                              (mk_comb(--`type_max`--, t)))
    int_types));

val type_size_def = Define`
  type_size t = type_max t - type_min t
`;
val type_range = Define`
  type_range t x = (type_min t <= x) /\ (x <= type_max t)
`;

(* 4.5 *)
val integral_promotions_def = Define`
  integral_promotions t =
    if t IN {Bool; BChar; Unsigned Char; Signed Char; Unsigned Short;
             Signed Short}
    then
      if type_range t SUBSET type_range (Signed Int) then
        Signed Int
      else
        Unsigned Int
    else t
`;

(* usual arithmetic conversions: 5 p9
*)
val ua_conversions_def = Define`
   ua_conversions t1 t2 =
    let t1' = integral_promotions t1 in
    let t2' = integral_promotions t2 in
      if Unsigned Long IN {t1'; t2'} then Unsigned Long
      else if {t1'; t2'} = {Unsigned Int; Signed Long} then
        if type_range (Unsigned Int) SUBSET type_range (Signed Long) then
          Signed Long
        else
          Unsigned Long
      else if Signed Long IN {t1'; t2'} then Signed Long
      else if Unsigned Int IN {t1'; t2'} then Unsigned Int
      else Signed Int
`;

(* utility function: given a set of abstract class names, determine if a type
   is an abstract class *)
val is_abstractty_def = Define`
  (is_abstractty abs_classes (Class sn) = sn IN abs_classes) /\
  (is_abstractty abs_classes _ = F)
`

(* wf_type is a predicate checking type "well-formedness".  It doesn't check
   the validity of class/struct declarations, only whether or not something
   might be a valid declarator *)
val wf_type_defn = Hol_defn "wf_type" `
  (* 8.3.2 p4 *)
  (wf_type abs_classes (Ptr ty) = ~ref_type ty /\
                                  wf_type abs_classes ty) /\

  (* 8.3.3 p3 *)
  (wf_type abs_classes (MPtr c ty) = ~ref_type ty /\ ~(ty = Void) /\
                                     wf_type abs_classes ty) /\
  (* 8.3.4 p1 *)
  (wf_type abs_classes (Array bt n) =
      ~(n = 0) /\ ~(bt = Void) /\
      ~function_type bt /\ ~ref_type bt /\
      ~is_abstractty abs_classes bt /\  wf_type abs_classes bt) /\

  (* 8.3.5 - note that variadic functions are not modelled
       para 6: return type not array or function
       para 3: arg type not array, function or void
     10.4
       para 3: arg and return type not abstract class
  *)
  (wf_type abs_classes (Function r a) =
        ~function_type r /\ ~array_type r /\ wf_type abs_classes r /\
        ~is_abstractty abs_classes r /\
        EVERY (\ty. ~function_type ty /\ ~(ty = Void) /\ ~array_type ty /\
                    ~is_abstractty abs_classes ty /\
                    wf_type abs_classes ty) a) /\

  (* 3.9.3 para 1 and para 2 *)
  (wf_type abs_classes (Const ty) =
     (object_type ty \/ (ty = Void)) /\ ~array_type ty /\
     wf_type abs_classes ty) /\

  (* all others are OK *)
  (wf_type absc ty = T)
`;

(* termination proof for the above *)
val (wf_type_def, wf_type_ind) = Defn.tprove(wf_type_defn,
  WF_REL_TAC `measure (CPP_Type_size o SND)` THEN
  SRW_TAC [ARITH_ss][] THEN Induct_on `a` THEN
  SRW_TAC [][] THEN FULL_SIMP_TAC (srw_ss() ++ ARITH_ss) []);

val _ = save_thm("wf_type_def", wf_type_def)
val _ = save_thm("wf_type_ind", wf_type_ind)

open BasicProvers
val _ = export_rewrites ["wf_type_def"]

(* SANITY *)
val type_classes = store_thm(
  "type_classes",
  ``(!t. (pointer_type t ==> ~arithmetic_type t) /\
         (pointer_type t ==> ~array_type t) /\
         (array_type t ==> ~arithmetic_type t) /\
         (integral_type t ==> arithmetic_type t) /\
         (pointer_type t ==> scalar_type t) /\
         (arithmetic_type t ==> scalar_type t) /\
         (arithmetic_type t ==> object_type t)) /\
    integral_type ptrdiff_t``,
  FULL_SIMP_TAC (srw_ss()) [arithmetic_type_def, scalar_type_def,
                            object_type_def] THEN
  CONJ_TAC THENL [
    Induct_on `t` THEN SRW_TAC [][],
    STRIP_ASSUME_TAC
      (REWRITE_RULE [NOT_IN_EMPTY, IN_INSERT] ptrdiff_t) THEN SRW_TAC [][]
  ]);

(* SANITY *)
val integral_types_well_formed = store_thm(
  "integral_types_well_formed",
  ``!t. integral_type t ==> !ac. wf_type ac t``,
  Induct_on `t` THEN SRW_TAC [][] THEN METIS_TAC [type_classes]);

(* SANITY *)
val arithmetic_types_well_formed = store_thm(
  "arithmetic_types_well_formed",
  ``!t. arithmetic_type t ==> !ac. wf_type ac t``,
  Induct_on `t` THEN SRW_TAC [][arithmetic_type_def] THEN
  METIS_TAC [type_classes]);

(* SANITY *)
val ua_converted_types_well_formed = store_thm(
  "ua_converted_types_well_formed",
  ``!t1 t2 ac. wf_type ac (ua_conversions t1 t2)``,
  SRW_TAC [][ua_conversions_def, LET_THM]);

val ptrdiff_t_well_formed = store_thm(
  "ptrdiff_t_well_formed",
  ``!ac. wf_type ac ptrdiff_t``,
  STRIP_ASSUME_TAC (SIMP_RULE (srw_ss()) [] ptrdiff_t) THEN
  ASM_SIMP_TAC (srw_ss()) []);

(* SANITY *)
val integral_promotions_safe = store_thm(
  "integral_promotions_safe",
  ``(!t. integral_type t ==> integral_type (integral_promotions t)) /\
    (!t. arithmetic_type t ==>
           arithmetic_type (integral_promotions t))``,
  CONJ_TAC THEN Cases_on `t` THEN
  SRW_TAC [][integral_promotions_def, arithmetic_type_def]);

(* SANITY *)
val ua_conversions_safe = store_thm(
  "ua_conversions_safe",
  ``!t1 t2. arithmetic_type t1 /\ arithmetic_type t2 ==>
            arithmetic_type (ua_conversions t1 t2)``,
  SRW_TAC [][arithmetic_type_def, LET_THM, integral_promotions_def,
             ua_conversions_def]);


val _ = export_theory();
