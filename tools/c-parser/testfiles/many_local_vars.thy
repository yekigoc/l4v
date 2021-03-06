(*
 * Copyright 2014, NICTA
 *
 * This software may be distributed and modified according to the terms of
 * the BSD 2-Clause license. Note that NO WARRANTY is provided.
 * See "LICENSE_BSD2.txt" for details.
 *
 * @TAG(NICTA_BSD)
 *)

theory many_local_vars
imports
  "../../../spec/machine/ARMMachineTypes"
  "../CTranslation"
begin

(* Avoid memory explosion caused by the C parser generating a huge record
 * containing local variables. *)
declare [[record_codegen = false]]

install_C_file "many_local_vars.c" [machinety=machine_state]

context "many_local_vars_global_addresses" begin
lemma "\<forall>\<sigma>. \<Gamma> \<turnstile>\<^bsub>/UNIV\<^esub> {\<sigma>} Call test_'proc
              {t. t may_not_modify_globals \<sigma>}"
  apply (tactic {* HoarePackage.vcg_tac "_modifies" "false" [] @{context} 1 *})
done
end

end
