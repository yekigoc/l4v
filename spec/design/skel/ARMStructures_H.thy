(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

theory ARMStructures_H
imports
  "../../lib/Lib"
  Types_H
  Hardware_H
begin

#INCLUDE_HASKELL SEL4/Object/Structures/ARM.lhs decls_only
#INCLUDE_HASKELL SEL4/Object/Structures/ARM.lhs instanceproofs
#INCLUDE_HASKELL SEL4/Object/Structures/ARM.lhs bodies_only

datatype arch_kernel_object_type =
    PDET
  | PTET
  | ASIDPoolT

primrec
  archTypeOf :: "arch_kernel_object \<Rightarrow> arch_kernel_object_type"
where
  "archTypeOf (KOPDE e) = PDET"
| "archTypeOf (KOPTE e) = PTET"
| "archTypeOf (KOASIDPool e) = ASIDPoolT"

end
