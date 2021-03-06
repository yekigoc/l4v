(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

theory PageTableDuplicates
imports Syscall_R
begin

lemma duplicate_address_set_simp:
  "\<lbrakk>koTypeOf m \<noteq> ArchT PDET; koTypeOf m \<noteq> ArchT PTET \<rbrakk>
  \<Longrightarrow> p && ~~ mask (vs_ptr_align m) = p"
  by (auto simp:vs_ptr_align_def koTypeOf_def 
    split:kernel_object.splits arch_kernel_object.splits)+

lemma valid_duplicates'_non_pd_pt_I:
  "\<lbrakk>koTypeOf ko \<noteq> ArchT PDET; koTypeOf ko \<noteq> ArchT PTET;
   vs_valid_duplicates' (ksPSpace s) ; ksPSpace s p = Some ko; koTypeOf ko = koTypeOf m\<rbrakk>
       \<Longrightarrow> vs_valid_duplicates' (ksPSpace s(p \<mapsto> m))"
  apply (subst vs_valid_duplicates'_def)
  apply (intro allI impI)
  apply (clarsimp split:if_splits simp:duplicate_address_set_simp option.splits)
  apply (intro conjI impI allI)
    apply (frule_tac p = x and p' = p in valid_duplicates'_D)
     apply assumption
    apply simp
   apply (simp add:duplicate_address_set_simp)+
  apply (drule_tac m = "ksPSpace s" 
    and p = x in valid_duplicates'_D)
     apply simp+
  done

lemma set_ep_valid_duplicate' [wp]:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
  setEndpoint ep v  \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:setEndpoint_def)
  apply (clarsimp simp: setObject_def split_def valid_def in_monad
                        projectKOs pspace_aligned'_def ps_clear_upd'
                        objBits_def[symmetric] lookupAround2_char1
                 split: split_if_asm)
  apply (frule pspace_storable_class.updateObject_type[where v = v,simplified])
  apply (clarsimp simp:updateObject_default_def assert_def bind_def 
    alignCheck_def in_monad when_def alignError_def magnitudeCheck_def
    assert_opt_def return_def fail_def split:if_splits option.splits)
   apply (rule_tac ko = ba in valid_duplicates'_non_pd_pt_I)
       apply simp+
  apply (rule_tac ko = ba in valid_duplicates'_non_pd_pt_I)
      apply simp+
  done

lemma set_aep_valid_duplicate' [wp]:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
  setAsyncEP ep v  \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:setAsyncEP_def)
  apply (clarsimp simp: setObject_def split_def valid_def in_monad
                        projectKOs pspace_aligned'_def ps_clear_upd'
                        objBits_def[symmetric] lookupAround2_char1
                 split: split_if_asm)
  apply (frule pspace_storable_class.updateObject_type[where v = v,simplified])
  apply (clarsimp simp:updateObject_default_def assert_def bind_def 
    alignCheck_def in_monad when_def alignError_def magnitudeCheck_def
    assert_opt_def return_def fail_def split:if_splits option.splits)
   apply (rule_tac ko = ba in valid_duplicates'_non_pd_pt_I)
       apply simp+
  apply (rule_tac ko = ba in valid_duplicates'_non_pd_pt_I)
      apply simp+
  done

lemma setCTE_valid_duplicates'[wp]:
 "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
  setCTE p cte \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:setCTE_def)
  apply (clarsimp simp: setObject_def split_def valid_def in_monad
                        projectKOs pspace_aligned'_def ps_clear_upd'
                        objBits_def[symmetric] lookupAround2_char1
                 split: split_if_asm)
  apply (frule pspace_storable_class.updateObject_type[where v = cte,simplified])
  apply (clarsimp simp:ObjectInstances_H.updateObject_cte assert_def bind_def 
    alignCheck_def in_monad when_def alignError_def magnitudeCheck_def
    assert_opt_def return_def fail_def typeError_def
    split:if_splits option.splits Structures_H.kernel_object.splits)
     apply (erule valid_duplicates'_non_pd_pt_I[rotated 3],simp+)+
  done

crunch valid_duplicates' [wp]: cteInsert "(\<lambda>s. vs_valid_duplicates' (ksPSpace s))"
  (wp: crunch_wps)

crunch valid_duplicates'[wp]: setupReplyMaster "(\<lambda>s. vs_valid_duplicates' (ksPSpace s))"
  (wp: crunch_wps)


(* we need the following lemma in Syscall_R *)
crunch inv[wp]: getRegister "P"

lemma doMachineOp_ksPSpace_inv[wp]:
  "\<lbrace>\<lambda>s. P (ksPSpace s)\<rbrace> doMachineOp f \<lbrace>\<lambda>ya s. P (ksPSpace s)\<rbrace>"
  by (simp add:doMachineOp_def split_def | wp)+

lemma setEP_valid_duplicates'[wp]:
  " \<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
  setEndpoint a b \<lbrace>\<lambda>_ s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:setEndpoint_def)
  apply (clarsimp simp: setObject_def split_def valid_def in_monad
                        projectKOs pspace_aligned'_def ps_clear_upd'
                        objBits_def[symmetric] lookupAround2_char1
                 split: split_if_asm)
  apply (frule pspace_storable_class.updateObject_type[where v = b,simplified])
  apply (clarsimp simp:updateObject_default_def assert_def bind_def 
    alignCheck_def in_monad when_def alignError_def magnitudeCheck_def
    assert_opt_def return_def fail_def typeError_def
    split:if_splits option.splits Structures_H.kernel_object.splits)
     apply (erule valid_duplicates'_non_pd_pt_I[rotated 3],simp+)+
  done

lemma setTCB_valid_duplicates'[wp]:
 "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
  setObject a (tcb::tcb) \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (clarsimp simp: setObject_def split_def valid_def in_monad
                        projectKOs pspace_aligned'_def ps_clear_upd'
                        objBits_def[symmetric] lookupAround2_char1
                 split: split_if_asm)
  apply (frule pspace_storable_class.updateObject_type[where v = tcb,simplified])
  apply (clarsimp simp:updateObject_default_def assert_def bind_def 
    alignCheck_def in_monad when_def alignError_def magnitudeCheck_def
    assert_opt_def return_def fail_def typeError_def
    split:if_splits option.splits Structures_H.kernel_object.splits)
     apply (erule valid_duplicates'_non_pd_pt_I[rotated 3],simp+)+
  done

crunch valid_duplicates'[wp]: threadSet "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(ignore: getObject setObject wp: setObject_ksInterrupt updateObject_default_inv)

lemma tcbSchedEnqueue_valid_duplicates'[wp]:
 "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
  tcbSchedEnqueue a \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  by (simp add:tcbSchedEnqueue_def unless_def setQueue_def | wp | wpc)+

crunch valid_duplicates'[wp]: rescheduleRequired "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(ignore: getObject setObject wp: setObject_ksInterrupt updateObject_default_inv)

lemma getExtraCptrs_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. P (ksPSpace s)\<rbrace> getExtraCPtrs a i  \<lbrace>\<lambda>r s. P (ksPSpace s)\<rbrace>"
  apply (simp add:getExtraCPtrs_def)
  apply (rule hoare_pre)
  apply (wpc|simp|wp mapM_wp')+
  done

crunch valid_duplicates'[wp]: getExtraCPtrs "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(ignore: getObject setObject wp: setObject_ksInterrupt asUser_inv updateObject_default_inv)

crunch valid_duplicates'[wp]: lookupExtraCaps "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(ignore: getObject setObject sequenceE 
  wp: setObject_ksInterrupt asUser_inv updateObject_default_inv mapME_wp)

crunch valid_duplicates'[wp]: setExtraBadge "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(ignore: getObject setObject sequenceE 
  wp: setObject_ksInterrupt asUser_inv updateObject_default_inv mapME_wp)

crunch valid_duplicates'[wp]: getReceiveSlots "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(ignore: getObject setObject sequenceE simp:unless_def getReceiveSlots_def
  wp: setObject_ksInterrupt asUser_inv updateObject_default_inv mapME_wp)

lemma transferCapsToSlots_duplicates'[wp]:
 "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace> 
  transferCapsToSlots ep diminish buffer n caps slots mi
  \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  by (rule transferCapsToSlots_pres1,wp)

crunch valid_duplicates'[wp]: transferCaps "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(ignore: getObject setObject sequenceE simp:unless_def
  wp: setObject_ksInterrupt asUser_inv updateObject_default_inv mapME_wp)

crunch valid_duplicates'[wp]: sendFaultIPC "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(wp: crunch_wps hoare_vcg_const_Ball_lift get_rs_cte_at' ignore: transferCapsToSlots
    simp: zipWithM_x_mapM ball_conj_distrib ignore:sequenceE mapME getObject setObject)

crunch valid_duplicates'[wp]: handleFault "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(wp: crunch_wps hoare_vcg_const_Ball_lift get_rs_cte_at' ignore: transferCapsToSlots
    simp: zipWithM_x_mapM ball_conj_distrib ignore:sequenceE mapME getObject setObject)

crunch valid_duplicates'[wp]: replyFromKernel "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(wp: crunch_wps hoare_vcg_const_Ball_lift get_rs_cte_at' ignore: transferCapsToSlots
    simp: zipWithM_x_mapM ball_conj_distrib ignore:sequenceE mapME getObject setObject)

crunch valid_duplicates'[wp]: insertNewCap "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(wp: crunch_wps hoare_vcg_const_Ball_lift get_rs_cte_at' ignore: transferCapsToSlots
    simp: zipWithM_x_mapM ball_conj_distrib ignore:sequenceE mapME getObject setObject)

lemma koTypeOf_pte:
  "koTypeOf ko = ArchT PTET \<Longrightarrow> \<exists>pte. ko = KOArch (KOPTE pte)"
  "archTypeOf ako = PTET \<Longrightarrow> \<exists>pte. ako = KOPTE pte"
  apply (case_tac ko,simp_all)
  apply (case_tac arch_kernel_object,simp_all)
  apply (case_tac ako,simp_all)
  done

lemma koTypeOf_pde:
  "koTypeOf ko = ArchT PDET \<Longrightarrow> \<exists>pde. ko = KOArch (KOPDE pde)"
  "archTypeOf ako = PDET \<Longrightarrow> \<exists>pde. ako = KOPDE pde"
  apply (case_tac ko,simp_all)
  apply (case_tac arch_kernel_object,simp_all)
  apply (case_tac ako,simp_all)
  done

lemma mapM_x_storePTE_updates:
  "\<lbrace>\<lambda>s. (\<forall>x\<in> set xs. pte_at' x s) 
     \<and> Q (\<lambda>x. if (x \<in> set xs) then Some (KOArch (KOPTE pte)) else (ksPSpace s) x) \<rbrace>
     mapM_x (swp storePTE pte) xs
   \<lbrace>\<lambda>r s. Q (ksPSpace s)\<rbrace>"
  apply (induct xs)
   apply (simp add: mapM_x_Nil)
  apply (simp add: mapM_x_Cons)
  apply (rule hoare_seq_ext, assumption)
  apply (thin_tac "valid ?P ?f ?Q")
  apply (simp add: storePTE_def setObject_def)
  apply (wp | simp add:split_def updateObject_default_def)+
  apply clarsimp
  apply (intro conjI ballI)
   apply (drule(1) bspec)
   apply (clarsimp simp:typ_at'_def ko_wp_at'_def
     objBits_simps archObjSize_def dest!:koTypeOf_pte
     split:  Structures_H.kernel_object.split_asm)
   apply (simp add:ps_clear_def dom_fun_upd2[unfolded fun_upd_def])
  apply (erule rsubst[where P=Q])
  apply (rule ext, clarsimp)
  apply (case_tac "(fst (lookupAround2 aa (ksPSpace s)))")
   apply (clarsimp simp:lookupAround2_None1)
  apply (clarsimp simp:lookupAround2_known1)
  done

lemma is_aligned_plus_bound:
  assumes al: "is_aligned p sz"
  assumes cmp: "sz \<le> lz"
  assumes b:  "b \<le> (2::word32) ^ sz - 1"
  assumes bound : "p < 2 ^ lz"
  assumes sz: "sz < word_bits"
  shows "p + b < 2 ^ lz"
  proof -
    have lower:"p + b \<le> p + (2 ^ sz - 1)"
      apply (rule word_plus_mono_right[OF b])
      apply (rule is_aligned_no_overflow'[OF al])
      done
    show ?thesis using bound sz
      apply -
      apply (rule le_less_trans[OF lower])
      apply (rule ccontr)
      apply (simp add:not_less)
      apply (drule neg_mask_mono_le[where n = sz])
      apply (subst (asm) is_aligned_neg_mask_eq)
       apply (rule is_aligned_weaken[OF is_aligned_triv cmp])
      apply (subst (asm) is_aligned_add_helper[THEN conjunct2,OF al])
       apply (simp add:word_bits_def)
      apply simp
    done
  qed

lemma page_table_at_set_list:
  "\<lbrakk>page_table_at' ptr s;pspace_aligned' s;sz \<le> ptBits;
   p && ~~ mask ptBits = ptr; is_aligned p sz; 2 \<le> sz\<rbrakk> \<Longrightarrow>
  set [p , p + 4 .e. p + mask sz] =
  {x. pte_at' x s \<and> x && ~~ mask sz = p}"
  apply (clarsimp simp:page_table_at'_def ptBits_def)
  apply (rule set_eqI)
  apply (rule iffI)
   apply (subst (asm) upto_enum_step_subtract)
    apply (simp add:field_simps mask_def)
    apply (erule is_aligned_no_overflow)
   apply (clarsimp simp:set_upto_enum_step_4
           image_def pageBits_def)
   apply (drule_tac x= "((p && mask 10) >> 2) + xb" in spec)
   apply (erule impE)
    apply (rule is_aligned_plus_bound[where lz = 8 and sz = "sz - 2" ,simplified])
        apply (rule is_aligned_shiftr)
        apply (rule is_aligned_andI1)
        apply (subgoal_tac "sz - 2 + 2 = sz")
         apply simp
        apply simp
       apply (simp add:field_simps)
      apply (simp add:shiftr_mask2)
      apply (simp add:mask_def not_less word_bits_def)
     apply (rule shiftr_less_t2n[where m = 8,simplified])
     apply (rule le_less_trans[OF _ mask_lt_2pn])
      apply (simp add:word_and_le1)
     apply simp
    apply (simp add:word_bits_def)
   apply (simp add:word_shiftl_add_distrib)
   apply (subst (asm) shiftr_shiftl1)
    apply simp+
   apply (subst (asm) is_aligned_neg_mask_eq[where n = 2])
    apply (rule is_aligned_weaken)
     apply (erule is_aligned_andI1)
    apply simp
   apply (simp add:mask_out_sub_mask field_simps)
   apply (clarsimp simp:typ_at'_def mask_add_aligned
     ko_wp_at'_def dom_def)
   apply (rule less_mask_eq[symmetric])
   apply (subst (asm) shiftr_mask2)
    apply simp
   apply (simp add:shiftl_less_t2n word_shiftl_add_distrib
     word_bits_def mask_def shiftr_mask2)
  apply (clarsimp simp:objBits_simps pageBits_def archObjSize_def
     split:Structures_H.kernel_object.splits arch_kernel_object.splits)
  apply (subst upto_enum_step_subtract)
   apply (rule is_aligned_no_wrap'[OF is_aligned_neg_mask])
    apply (rule le_refl)
   apply (simp add:mask_lt_2pn word_bits_def)
  apply (simp add:image_def)
  apply (rule_tac x = "x && mask sz" in bexI)
   apply (simp add:mask_out_sub_mask)
  apply (simp add:set_upto_enum_step_4 image_def)
  apply (rule_tac x = "x && mask sz >> 2" in bexI)
   apply (subst shiftr_shiftl1)
    apply simp
   apply simp
   apply (subst is_aligned_neg_mask_eq)
    apply (rule is_aligned_andI1)
    apply (clarsimp simp: typ_at'_def ko_wp_at'_def
      dest!: koTypeOf_pte)
    apply (drule pspace_alignedD')
     apply simp
    apply (simp add:objBits_simps archObjSize_def)
   apply simp
  apply clarsimp
  apply (rule le_shiftr)
  apply (simp add:word_and_le1)
  done

lemma page_directory_at_set_list:
  "\<lbrakk>page_directory_at' ptr s;pspace_aligned' s;sz \<le> pdBits;
   p && ~~ mask pdBits = ptr; is_aligned p sz; 2 \<le> sz\<rbrakk> \<Longrightarrow>
  set [p , p + 4 .e. p + mask sz] =
  {x. pde_at' x s \<and> x && ~~ mask sz = p}"
  apply (clarsimp simp:page_directory_at'_def pdBits_def)
  apply (rule set_eqI)
  apply (rule iffI)
   apply (subst (asm) upto_enum_step_subtract)
    apply (simp add:field_simps mask_def)
    apply (erule is_aligned_no_overflow)
   apply (clarsimp simp:set_upto_enum_step_4
           image_def pageBits_def)
   apply (drule_tac x= "((p && mask 14) >> 2) + xb" in spec)
   apply (erule impE)
    apply (rule is_aligned_plus_bound[where lz = 12 and sz = "sz - 2" ,simplified])
        apply (rule is_aligned_shiftr)
        apply (rule is_aligned_andI1)
        apply (subgoal_tac "sz - 2 + 2 = sz")
         apply simp
        apply simp
       apply (simp add:field_simps)
      apply (simp add:shiftr_mask2)
      apply (simp add:mask_def not_less word_bits_def)
     apply (rule shiftr_less_t2n[where m = 12,simplified])
     apply (rule le_less_trans[OF _ mask_lt_2pn])
      apply (simp add:word_and_le1)
     apply simp
    apply (simp add:word_bits_def)
   apply (simp add:word_shiftl_add_distrib)
   apply (subst (asm) shiftr_shiftl1)
    apply simp+
   apply (subst (asm) is_aligned_neg_mask_eq[where n = 2])
    apply (rule is_aligned_weaken)
     apply (erule is_aligned_andI1)
    apply simp
   apply (simp add:mask_out_sub_mask field_simps)
   apply (clarsimp simp:typ_at'_def mask_add_aligned
     ko_wp_at'_def dom_def)
   apply (rule less_mask_eq[symmetric])
   apply (subst (asm) shiftr_mask2)
    apply simp
   apply (simp add:shiftl_less_t2n word_shiftl_add_distrib
     word_bits_def mask_def shiftr_mask2)
  apply (clarsimp simp:objBits_simps pageBits_def archObjSize_def
     split:Structures_H.kernel_object.splits arch_kernel_object.splits)
  apply (subst upto_enum_step_subtract)
   apply (rule is_aligned_no_wrap'[OF is_aligned_neg_mask])
    apply (rule le_refl)
   apply (simp add:mask_lt_2pn word_bits_def)
  apply (simp add:image_def)
  apply (rule_tac x = "x && mask sz" in bexI)
   apply (simp add:mask_out_sub_mask)
  apply (simp add:set_upto_enum_step_4 image_def)
  apply (rule_tac x = "x && mask sz >> 2" in bexI)
   apply (subst shiftr_shiftl1)
    apply simp
   apply simp
   apply (subst is_aligned_neg_mask_eq)
    apply (rule is_aligned_andI1)
    apply (clarsimp simp: typ_at'_def ko_wp_at'_def
      dest!: koTypeOf_pde)
    apply (drule pspace_alignedD')
     apply simp
    apply (simp add:objBits_simps archObjSize_def)
   apply simp
  apply clarsimp
  apply (rule le_shiftr)
  apply (simp add:word_and_le1)
  done

lemma irrelevant_ptr:
  "\<lbrakk>p && ~~ mask z \<noteq> p' && ~~ mask z; 6\<le>z \<rbrakk>
  \<Longrightarrow>  p && ~~ mask (vs_ptr_align a) \<noteq> p' && ~~ mask (vs_ptr_align a)"
  apply (rule ccontr)
  apply (case_tac a,simp_all 
    add:vs_ptr_align_def
    split:arch_kernel_object.splits
    Hardware_H.pte.splits
    Hardware_H.pde.splits)
   apply (drule arg_cong[where f = "\<lambda>x. x && ~~ mask z"])
   apply (simp add:mask_lower_twice ptBits_def)
  apply (drule arg_cong[where f = "\<lambda>x. x && ~~ mask z"])
  apply (simp add:mask_lower_twice ptBits_def)
  done

lemma page_table_at_pte_atD':
  "\<lbrakk>page_table_at' p s;is_aligned p' 2; p' && ~~ mask ptBits = p\<rbrakk> \<Longrightarrow> pte_at' p' s"
  apply (clarsimp simp:page_table_at'_def)
  apply (drule_tac x = "p' && mask ptBits >> 2" in spec)
  apply (erule impE)
   apply (rule shiftr_less_t2n[where m = 8,simplified])
   apply (rule le_less_trans[OF word_and_le1])
   apply (simp add:ptBits_def mask_def pageBits_def)
  apply (subst (asm) shiftr_shiftl1)
   apply simp
  apply simp
  apply (subst (asm) is_aligned_neg_mask_eq[where n = 2])
   apply (simp add:aligned_after_mask)
  apply (simp add:mask_out_sub_mask)
  done

lemma mapM_x_storePTE_update_helper:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)
    \<and> pspace_aligned' s 
    \<and> page_table_at' ptr s
    \<and> word && ~~ mask ptBits = ptr
    \<and> sz \<le> ptBits \<and> 6 \<le> sz
    \<and> is_aligned word sz
    \<and> xs = [word , word + 4 .e. word + (mask sz)] 
  \<rbrace>
  mapM_x (swp storePTE pte) xs
  \<lbrace>\<lambda>y s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (wp mapM_x_storePTE_updates)
  apply clarsimp
  apply (frule(2) page_table_at_set_list)
     apply simp+
  apply (subst vs_valid_duplicates'_def)
  apply clarsimp
  apply (intro conjI impI)
   apply clarsimp
   apply (thin_tac "?x = ?y")
   apply (simp add:mask_lower_twice)
   apply (subgoal_tac "x && ~~ mask sz = y && ~~ mask sz")
    apply (drule(1) page_table_at_pte_atD')
     apply (drule mask_out_first_mask_some[where m = ptBits])
      apply (simp add:vs_ptr_align_def split:Hardware_H.pte.splits)
     apply (simp add:mask_lower_twice vs_ptr_align_def
      split:Hardware_H.pte.splits)
    apply (clarsimp simp:typ_at'_def ko_wp_at'_def)
   apply (clarsimp simp:vs_ptr_align_def
      split:arch_kernel_obj.splits Structures_H.kernel_object.splits
      split:Hardware_H.pte.splits)
   apply (drule mask_out_first_mask_some[where m = sz])
    apply simp
   apply (simp add:mask_lower_twice)
  apply clarsimp
  apply (intro conjI impI)
   apply (thin_tac "?x = ?y")
   apply (clarsimp split:option.splits)
   apply (subgoal_tac "x && ~~ mask sz = y && ~~ mask sz")
    apply (drule_tac p' = x in page_table_at_pte_atD')
      apply (drule pspace_alignedD')
       apply simp
      apply (simp add:objBits_simps archObjSize_def
        is_aligned_weaken[where y = 2] pageBits_def
        split:kernel_object.splits arch_kernel_object.splits)
     apply (simp add:mask_lower_twice)
     apply (drule mask_out_first_mask_some[where m = ptBits])
      apply (simp add:vs_ptr_align_def
        split:kernel_object.splits arch_kernel_object.splits
        Hardware_H.pte.splits Hardware_H.pde.splits)
     apply (subst (asm) mask_lower_twice)
      apply (simp add:vs_ptr_align_def
        split:kernel_object.splits arch_kernel_object.splits
        Hardware_H.pte.splits Hardware_H.pde.splits)
     apply simp
    apply (simp add:vs_ptr_align_def
      split:kernel_object.splits arch_kernel_object.splits
      Hardware_H.pte.splits)
   apply (simp add:mask_lower_twice)
   apply (drule mask_out_first_mask_some[where m = sz])
    apply (simp add:vs_ptr_align_def
      split:kernel_object.splits arch_kernel_object.splits
      Hardware_H.pte.splits Hardware_H.pde.splits)
   apply (subst (asm) mask_lower_twice)
    apply (simp add:vs_ptr_align_def
      split:kernel_object.splits arch_kernel_object.splits
      Hardware_H.pte.splits Hardware_H.pde.splits)
   apply simp
  apply (clarsimp split:option.splits)
  apply (drule_tac p' = y in valid_duplicates'_D)
     apply simp+
  done

lemma page_directory_at_pde_atD':
  "\<lbrakk>page_directory_at' p s;is_aligned p' 2; p' && ~~ mask pdBits = p\<rbrakk> \<Longrightarrow> pde_at' p' s"
  apply (clarsimp simp:page_directory_at'_def)
  apply (drule_tac x = "p' && mask pdBits >> 2" in spec)
  apply (erule impE)
   apply (rule shiftr_less_t2n[where m = 12,simplified])
   apply (rule le_less_trans[OF word_and_le1])
   apply (simp add:pdBits_def mask_def pageBits_def)
  apply (subst (asm) shiftr_shiftl1)
   apply simp
  apply simp
  apply (subst (asm) is_aligned_neg_mask_eq[where n = 2])
   apply (simp add:aligned_after_mask)
  apply (simp add:mask_out_sub_mask)
  done

lemma mapM_x_storePDE_updates:
  "\<lbrace>\<lambda>s. (\<forall>x\<in> set xs. pde_at' x s) 
     \<and> Q (\<lambda>x. if (x \<in> set xs) then Some (KOArch (KOPDE pte)) else (ksPSpace s) x) \<rbrace>
     mapM_x (swp storePDE pte) xs
   \<lbrace>\<lambda>r s. Q (ksPSpace s)\<rbrace>"
  apply (induct xs)
   apply (simp add: mapM_x_Nil)
  apply (simp add: mapM_x_Cons)
  apply (rule hoare_seq_ext, assumption)
  apply (thin_tac "valid ?P ?f ?Q")
  apply (simp add: storePDE_def setObject_def)
  apply (wp | simp add:split_def updateObject_default_def)+
  apply clarsimp
  apply (intro conjI ballI)
   apply (drule(1) bspec)
   apply (clarsimp simp:typ_at'_def ko_wp_at'_def
     objBits_simps archObjSize_def dest!:koTypeOf_pde
     split:  Structures_H.kernel_object.split_asm)
   apply (simp add:ps_clear_def dom_fun_upd2[unfolded fun_upd_def])
  apply (erule rsubst[where P=Q])
  apply (rule ext, clarsimp)
  apply (case_tac "(fst (lookupAround2 aa (ksPSpace s)))")
   apply (clarsimp simp:lookupAround2_None1)
  apply (clarsimp simp:lookupAround2_known1)
  done

lemma mapM_x_storePDE_update_helper:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)
    \<and> pspace_aligned' s 
    \<and> page_directory_at' ptr s
    \<and> word && ~~ mask pdBits = ptr
    \<and> sz \<le> pdBits \<and> 6 \<le> sz
    \<and> is_aligned word sz
    \<and> xs = [word , word + 4 .e. word + (mask sz)] 
  \<rbrace>
  mapM_x (swp storePDE pte) xs
  \<lbrace>\<lambda>y s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (wp mapM_x_storePDE_updates)
  apply clarsimp
  apply (frule(2) page_directory_at_set_list)
     apply simp+
  apply (subst vs_valid_duplicates'_def)
  apply clarsimp
  apply (intro conjI impI)
   apply clarsimp
   apply (thin_tac "?x = ?y")
   apply (simp add:mask_lower_twice)
   apply (subgoal_tac "y && ~~ mask sz = x && ~~ mask sz")
    apply (drule(1) page_directory_at_pde_atD')
     apply (drule mask_out_first_mask_some[where m = pdBits])
      apply (simp add:vs_ptr_align_def split:Hardware_H.pde.splits)
     apply (simp add:mask_lower_twice vs_ptr_align_def
      split:Hardware_H.pde.splits)
    apply (clarsimp simp:typ_at'_def ko_wp_at'_def)
   apply (clarsimp simp:vs_ptr_align_def
      split:arch_kernel_obj.splits Structures_H.kernel_object.splits
      split:Hardware_H.pde.splits)
   apply (drule mask_out_first_mask_some[where m = sz])
    apply simp
   apply (simp add:mask_lower_twice)
  apply clarsimp
  apply (intro conjI impI)
   apply (thin_tac "?x = ?y")
   apply (clarsimp split:option.splits)
   apply (subgoal_tac "x && ~~ mask sz = y && ~~ mask sz")
    apply (drule_tac p' = x in page_directory_at_pde_atD')
      apply (drule pspace_alignedD')
       apply simp
      apply (simp add:objBits_simps archObjSize_def
        is_aligned_weaken[where y = 2] pageBits_def
        split:kernel_object.splits arch_kernel_object.splits)
     apply (simp add:mask_lower_twice)
     apply (drule mask_out_first_mask_some[where m = pdBits])
      apply (simp add:vs_ptr_align_def
        split:kernel_object.splits arch_kernel_object.splits
        Hardware_H.pte.splits Hardware_H.pde.splits)
     apply (subst (asm) mask_lower_twice)
      apply (simp add:vs_ptr_align_def
        split:kernel_object.splits arch_kernel_object.splits
        Hardware_H.pte.splits Hardware_H.pde.splits)
     apply simp
    apply (simp add:vs_ptr_align_def
      split:kernel_object.splits arch_kernel_object.splits
      Hardware_H.pde.splits)
   apply (simp add:mask_lower_twice)
   apply (drule mask_out_first_mask_some[where m = sz])
    apply (simp add:vs_ptr_align_def
      split:kernel_object.splits arch_kernel_object.splits
      Hardware_H.pte.splits Hardware_H.pde.splits)
   apply (subst (asm) mask_lower_twice)
    apply (simp add:vs_ptr_align_def
      split:kernel_object.splits arch_kernel_object.splits
      Hardware_H.pte.splits Hardware_H.pde.splits)
   apply simp
  apply (clarsimp split:option.splits)
  apply (drule_tac p' = y in valid_duplicates'_D)
     apply simp+
  done

lemma vs_ptr_align_upbound:
  "vs_ptr_align a \<le> 6"
    by (simp add:vs_ptr_align_def
      split:Structures_H.kernel_object.splits
      arch_kernel_object.splits
      Hardware_H.pde.splits Hardware_H.pte.splits)

lemma is_aligned_le_mask: 
  "\<lbrakk>is_aligned a n; a\<le>b\<rbrakk> \<Longrightarrow> a \<le> b && ~~ mask n"
  apply (drule neg_mask_mono_le)
  apply (subst (asm) is_aligned_neg_mask_eq)
  apply simp+
  done


lemma global_pd_offset:
  "\<lbrakk>is_aligned ptr pdBits ; x \<in> {ptr + (kernelBase >> 20 << 2)..ptr + 2 ^ pdBits - 1}\<rbrakk>
  \<Longrightarrow> ptr  + (x && mask pdBits) = x"
  apply (rule mask_eqI[where n = pdBits])
   apply (simp add:mask_add_aligned mask_twice pdBits_def pageBits_def)
  apply (subst mask_out_sub_mask)
  apply (simp add:mask_add_aligned mask_twice pdBits_def pageBits_def)
  apply clarsimp
  apply (drule neg_mask_mono_le[where n = 14])
  apply (drule neg_mask_mono_le[where n = 14])
  apply (simp add:field_simps)
  apply (frule_tac d1 = "0x3FFF" and p1="ptr" in is_aligned_add_helper[THEN conjunct2])
   apply simp
  apply (frule_tac d1 = "kernelBase >> 20 << 2" and p1 = "ptr" 
    in is_aligned_add_helper[THEN conjunct2])
   apply (simp add:kernelBase_def)
  apply simp
  done

lemma globalPDEWindow_neg_mask:
  "\<lbrakk>x && ~~ mask (vs_ptr_align a) = y && ~~ mask (vs_ptr_align a);is_aligned ptr pdBits\<rbrakk>
  \<Longrightarrow> y \<in> {ptr + (kernelBase >> 20 << 2)..ptr + (2 ^ (pdBits) - 1)} 
  \<Longrightarrow> x \<in> {ptr + (kernelBase >> 20 << 2)..ptr + (2 ^ (pdBits) - 1)}"
  apply (clarsimp simp:kernelBase_def)
  apply (intro conjI)
   apply (rule_tac y = "y &&~~ mask (vs_ptr_align a)" in order_trans)
    apply (rule is_aligned_le_mask)
     apply (rule is_aligned_weaken[OF _ vs_ptr_align_upbound])
     apply (erule aligned_add_aligned[OF is_aligned_weaken[OF _ le_refl]])
      apply (simp add:is_aligned_def)
     apply (simp add:pdBits_def pageBits_def)
    apply simp
   apply (drule sym)
   apply (simp add:word_and_le2)
  apply (drule_tac x = y in neg_mask_mono_le[where n = pdBits])
  apply (subst (asm) is_aligned_add_helper)
    apply simp
   apply (simp add:pdBits_def pageBits_def)
  apply (rule order_trans[OF and_neg_mask_plus_mask_mono[where n = pdBits]])
  apply (drule mask_out_first_mask_some[where m = pdBits])
   apply (cut_tac a = a in vs_ptr_align_upbound)
   apply (simp add:pdBits_def pageBits_def)
  apply (cut_tac a = a in vs_ptr_align_upbound)
  apply (drule le_trans[where k = 14])
   apply simp
  apply (simp add:and_not_mask_twice max_def
    pdBits_def pageBits_def)
  apply (simp add:mask_def)
  apply (subst add.commute)
  apply (subst add.commute[where a = ptr])
  apply (rule word_plus_mono_right)
   apply simp
  apply (rule olen_add_eqv[THEN iffD2])
  apply (simp add:field_simps)
  apply (erule is_aligned_no_wrap')
  apply simp
  done

lemma copyGlobalMappings_ksPSpace_stable:
  notes blah[simp del] =  atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex
          atLeastAtMost_iff
  assumes ptr_al: "is_aligned ptr pdBits"
  shows
   "\<lbrace>\<lambda>s. ksPSpace s x = ko \<and> pspace_distinct' s \<and> pspace_aligned' s \<and> 
    is_aligned (armKSGlobalPD (ksArchState s)) pdBits\<rbrace>
   copyGlobalMappings ptr
   \<lbrace>\<lambda>_ s. ksPSpace s x = (if x \<in> {ptr + (kernelBase >> 20 << 2)..ptr + (2 ^ pdBits - 1)}
           then ksPSpace s ((armKSGlobalPD (ksArchState s)) + (x && mask pdBits))
           else ko)\<rbrace>"
  proof -
    have not_aligned_eq_None:
      "\<And>x s. \<lbrakk>\<not> is_aligned x 2; pspace_aligned' s\<rbrakk> \<Longrightarrow> ksPSpace s x = None"
      apply (rule ccontr)
      apply clarsimp
      apply (drule(1) pspace_alignedD')
      apply (drule is_aligned_weaken[where y = 2])
       apply (case_tac y, simp_all add:objBits_simps pageBits_def)
      apply (simp add:archObjSize_def pageBits_def
        split:arch_kernel_object.splits)
      done
    have ptr_eqD:
      "\<And>p a b. \<lbrakk>p + a = ptr + b;is_aligned p pdBits;
            a < 2^ pdBits; b < 2^pdBits \<rbrakk>
       \<Longrightarrow> p = ptr"
      apply (drule arg_cong[where f = "\<lambda>x. x && ~~ mask pdBits"])
      apply (subst (asm) is_aligned_add_helper[THEN conjunct2])
        apply simp
       apply simp
      apply (subst (asm) is_aligned_add_helper[THEN conjunct2])
        apply (simp add:ptr_al)
       apply simp
      apply simp
      done
    have postfix_listD:
      "\<And>a as. suffixeq (a # as) [kernelBase >> 20.e.2 ^ (pdBits - 2) - 1]
       \<Longrightarrow> a \<in> set [kernelBase >> 20 .e. 2 ^ (pdBits - 2) - 1]"
       apply (clarsimp simp:suffixeq_def)
       apply (subgoal_tac "a \<in> set (zs @ a # as)")
        apply (drule sym)
        apply simp
       apply simp
       done
     have in_rangeD: "\<And>x. 
       \<lbrakk>kernelBase >> 20 \<le> x; x \<le> 2 ^ (pdBits - 2) - 1\<rbrakk>
       \<Longrightarrow> ptr + (x << 2) \<in> {ptr + (kernelBase >> 20 << 2)..ptr + (2 ^ pdBits - 1)}"
       apply (clarsimp simp:blah)
       apply (intro conjI)
        apply (rule word_plus_mono_right)
         apply (simp add:kernelBase_def pdBits_def pageBits_def)
         apply (word_bitwise,simp)
        apply (rule is_aligned_no_wrap'[OF ptr_al])
        apply (simp add:pdBits_def pageBits_def)
        apply (word_bitwise,simp)
       apply (rule word_plus_mono_right)
        apply (simp add:pdBits_def pageBits_def)
        apply (word_bitwise,simp)
       apply (rule is_aligned_no_wrap'[OF ptr_al])
       apply (simp add:pdBits_def pageBits_def)
       done

     have offset_bound:
       "\<And>x. \<lbrakk>is_aligned ptr 14;ptr + (kernelBase >> 20 << 2) \<le> x; x \<le> ptr + 0x3FFF\<rbrakk>
        \<Longrightarrow> x - ptr < 0x4000"
        apply (clarsimp simp: kernelBase_def field_simps)
        apply unat_arith
        done

  show ?thesis
  apply (case_tac "\<not> is_aligned x 2")
   apply (rule hoare_name_pre_state)
   apply (clarsimp)
   apply (rule_tac Q = "\<lambda>r s. is_aligned (armKSGlobalPD (ksArchState s)) 2
      \<and> pspace_aligned' s" in hoare_post_imp)
    apply (frule_tac x = x in not_aligned_eq_None)
     apply simp
    apply (frule_tac x = x and s = sa in not_aligned_eq_None)
     apply simp
    apply clarsimp
    apply (drule_tac  x = "armKSGlobalPD (ksArchState sa) + (x && mask pdBits)"
      and  s = sa in not_aligned_eq_None[rotated])
     apply (subst is_aligned_mask)
     apply (simp add: mask_add_aligned mask_twice)
     apply (simp add:is_aligned_mask pdBits_def mask_def)
    apply simp
   apply (wp|simp)+
   apply (erule is_aligned_weaken)
   apply (simp add:pdBits_def)
  apply (simp add: copyGlobalMappings_def)
  apply (rule hoare_name_pre_state)
  apply (rule hoare_conjI)
   apply (rule hoare_pre)
    apply (rule hoare_vcg_const_imp_lift)
    apply wp
     apply (rule_tac V="\<lambda>xs s. \<forall>x \<in> (set [kernelBase >> 20.e.2 ^ (pdBits - 2) - 1] - set xs).
                                 ksPSpace s (ptr + (x << 2)) = ksPSpace s (globalPD + (x << 2))"
             and I="\<lambda>s'. globalPD = (armKSGlobalPD (ksArchState s')) 
                       \<and> globalPD = (armKSGlobalPD (ksArchState s))"
       in mapM_x_inv_wp2)
      apply (cut_tac ptr_al)
      apply (clarsimp simp:blah pdBits_def pageBits_def)
      apply (drule_tac x="x - ptr >> 2" in spec)
      apply (frule offset_bound)
       apply simp+
      apply (erule impE)
       apply (rule conjI)
        apply (rule le_shiftr[where u="kernelBase >> 18" and n=2, simplified shiftr_shiftr, simplified])
        apply (rule word_le_minus_mono_left[where x=ptr and y="(kernelBase >> 18) + ptr", simplified])
         apply (simp add: kernelBase_def field_simps)
        apply (simp add:field_simps)
        apply (erule is_aligned_no_wrap')
        apply (simp add: kernelBase_def pdBits_def pageBits_def)
       apply (drule le_m1_iff_lt[THEN iffD1,THEN iffD2,rotated])
        apply simp
       apply (drule le_shiftr[where u = "x - ptr" and n = 2])
       apply simp
      apply (cut_tac b = 2 and c = 2 and a = "x - ptr" in shiftr_shiftl1)
       apply simp
      apply simp
      apply (cut_tac n = 2 and p = "x - ptr" in is_aligned_neg_mask_eq)
       apply (erule aligned_sub_aligned)
        apply (erule is_aligned_weaken,simp)
       apply simp
      apply simp
      apply (drule_tac t = x in
        global_pd_offset[symmetric,unfolded pdBits_def pageBits_def,simplified])
       apply (clarsimp simp:blah field_simps)
      apply (subgoal_tac "x && mask 14 = x - ptr")
       apply clarsimp
      apply (simp add:field_simps)
     apply (wp hoare_vcg_all_lift getPDE_wp mapM_x_wp'
        | simp add: storePDE_def setObject_def split_def
        updateObject_default_def
        split: option.splits)+
     apply (clarsimp simp:objBits_simps archObjSize_def)
     apply (clarsimp simp:obj_at'_def objBits_simps
        projectKO_def projectKO_opt_pde fail_def return_def
        split: Structures_H.kernel_object.splits
        arch_kernel_object.splits)
     apply (drule_tac x = xa in bspec)
      apply simp
      apply (rule ccontr)
      apply simp
     apply clarsimp
     apply (drule(1) ptr_eqD)
       apply (rule shiftl_less_t2n)
        apply (simp add:pdBits_def pageBits_def )
        apply (rule le_m1_iff_lt[THEN iffD1,THEN iffD1])
         apply simp
        apply simp
       apply (simp add:pdBits_def pageBits_def)
      apply (rule shiftl_less_t2n)
       apply (drule postfix_listD)
       apply (clarsimp simp:pdBits_def)
      apply (simp add:pdBits_def pageBits_def)
     apply simp
    apply wp
   apply (clarsimp simp:objBits_simps archObjSize_def)
  apply (rule hoare_name_pre_state)
  apply (rule hoare_pre)
   apply (rule hoare_vcg_const_imp_lift)
   apply wp
    apply (rule_tac Q = "\<lambda>r s'. ksPSpace s' x = ksPSpace s x \<and> globalPD = armKSGlobalPD (ksArchState s)"
      in hoare_post_imp)
     apply (wp hoare_vcg_all_lift getPDE_wp mapM_x_wp'
        | simp add: storePDE_def setObject_def split_def
        updateObject_default_def
        split: option.splits)+
    apply (clarsimp simp:objBits_simps archObjSize_def dest!:in_rangeD)
   apply wp
  apply simp
  done
qed

lemma copyGlobalMappings_ksPSpace_same:
  notes blah[simp del] =  atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex
          atLeastAtMost_iff
  shows
  "\<lbrakk>is_aligned ptr pdBits\<rbrakk> \<Longrightarrow>
   \<lbrace>\<lambda>s. ksPSpace s x = ko \<and> pspace_distinct' s \<and> pspace_aligned' s \<and> 
    is_aligned (armKSGlobalPD (ksArchState s)) pdBits \<and> ptr = armKSGlobalPD (ksArchState s)\<rbrace>
   copyGlobalMappings ptr
   \<lbrace>\<lambda>_ s. ksPSpace s x = ko\<rbrace>"
  apply (simp add:copyGlobalMappings_def)
  apply (rule hoare_name_pre_state)
  apply clarsimp
  apply (rule hoare_pre)
   apply wp
    apply (rule_tac Q = "\<lambda>r s'. ksPSpace s' x = ksPSpace s x \<and> globalPD = armKSGlobalPD (ksArchState s)"
      in hoare_post_imp)
     apply simp
    apply (wp hoare_vcg_all_lift getPDE_wp mapM_x_wp'
    | simp add: storePDE_def setObject_def split_def
    updateObject_default_def
    split: option.splits)+
    apply (clarsimp simp:objBits_simps archObjSize_def)
    apply (clarsimp simp:obj_at'_def objBits_simps
      projectKO_def projectKO_opt_pde fail_def return_def
      split: Structures_H.kernel_object.splits
      arch_kernel_object.splits)
   apply wp
  apply simp
  done

lemmas copyGlobalMappings_ksPSpaceD = use_valid[OF _ copyGlobalMappings_ksPSpace_stable]
lemmas copyGlobalMappings_ksPSpace_sameD = use_valid[OF _ copyGlobalMappings_ksPSpace_same]

lemma copyGlobalMappings_ksPSpace_concrete:
  notes blah[simp del] =  atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex
          atLeastAtMost_iff
  assumes monad: "(r, s') \<in> fst (copyGlobalMappings ptr s)"
  and ps: "pspace_distinct' s" "pspace_aligned' s"
  and al: "is_aligned (armKSGlobalPD (ksArchState s)) pdBits"
          "is_aligned ptr pdBits"
  shows   "ksPSpace s' = (\<lambda>x. 
           (if x \<in> {ptr + (kernelBase >> 20 << 2)..ptr + (2 ^ pdBits - 1)}
            then ksPSpace s ((x && mask pdBits) + armKSGlobalPD (ksArchState s)) else ksPSpace s x))"
  proof -
    have pd: "\<And>pd. \<lbrace>\<lambda>s. armKSGlobalPD (ksArchState s) = pd \<rbrace>
              copyGlobalMappings ptr \<lbrace>\<lambda>r s. armKSGlobalPD (ksArchState s) = pd \<rbrace>"
      by wp
    have comp: "\<And>x. x \<in> {ptr + (kernelBase >> 20 << 2)..ptr + 2 ^ pdBits - 1}
      \<Longrightarrow> ptr  + (x && mask pdBits) = x"
      using al
      apply -
      apply (rule mask_eqI[where n = pdBits])
       apply (simp add:mask_add_aligned mask_twice pdBits_def pageBits_def)
      apply (subst mask_out_sub_mask)
      apply (simp add:mask_add_aligned mask_twice pdBits_def pageBits_def)
      apply (clarsimp simp:blah)
      apply (drule neg_mask_mono_le[where n = 14])
      apply (drule neg_mask_mono_le[where n = 14])
      apply (simp add:field_simps)
      apply (frule_tac d1 = "0x3FFF" and p1="ptr" in is_aligned_add_helper[THEN conjunct2])
       apply simp
      apply (frule_tac d1 = "kernelBase >> 20 << 2" and p1 = "ptr" 
        in is_aligned_add_helper[THEN conjunct2])
       apply (simp add:kernelBase_def)
      apply simp
      done
      
  show ?thesis
    using ps al monad
    apply -
    apply (rule ext)
    apply (frule_tac x = x in copyGlobalMappings_ksPSpaceD)
     apply simp+
    apply (clarsimp split:if_splits)
    apply (frule_tac x = "(armKSGlobalPD (ksArchState s') + (x && mask pdBits))"
     in copyGlobalMappings_ksPSpaceD)
     apply simp+
    apply (drule use_valid[OF _ pd])
     apply simp
    apply (clarsimp split:if_splits 
      simp:mask_add_aligned field_simps)
    apply (frule comp)
    apply (clarsimp simp:pdBits_def pageBits_def
      mask_twice blah)
    apply (drule_tac y = "armKSGlobalPD ?a + ?b" in neg_mask_mono_le[where n = 14])
    apply (drule_tac x = "armKSGlobalPD ?a + ?b" in neg_mask_mono_le[where n = 14])
    apply (frule_tac d1 = "x && mask 14" in is_aligned_add_helper[THEN conjunct2])
     apply (simp add:mask_def)
     apply (rule le_less_trans[OF word_and_le1])
     apply simp
    apply (frule_tac d1 = "kernelBase >> 20 << 2" in is_aligned_add_helper[THEN conjunct2])
     apply (simp add:kernelBase_def)
    apply (simp add:field_simps)
    apply (frule_tac d1 = "0x3FFF" and p1="ptr" in is_aligned_add_helper[THEN conjunct2])
     apply simp
    apply (frule_tac d1 = "kernelBase >> 20 << 2" and p1 = "ptr" 
      in is_aligned_add_helper[THEN conjunct2])
     apply (simp add:kernelBase_def)
    apply simp
    apply (cut_tac copyGlobalMappings_ksPSpace_sameD)
       apply simp
      apply (rule monad)
     apply (simp add:al)
    apply (simp add:al)
  done
qed

  
lemma copyGlobalMappings_valid_duplicates':
  notes blah[simp del] =  atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex
          atLeastAtMost_iff
  shows "\<lbrace>(\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and pspace_distinct'
    and pspace_aligned'
    and (\<lambda>s. is_aligned (armKSGlobalPD (ksArchState s)) pdBits)
    and K (is_aligned ptr pdBits)\<rbrace>
  copyGlobalMappings ptr \<lbrace>\<lambda>y s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  proof -
      have neg_mask_simp: "\<And>x ptr' ptr a. 
      \<lbrakk>is_aligned ptr pdBits\<rbrakk>
      \<Longrightarrow> x + ptr && ~~ mask (vs_ptr_align a) = (x && ~~ mask (vs_ptr_align a)) 
      + ptr"
        apply (cut_tac a = a in vs_ptr_align_upbound)
        apply (subst add.commute)
        apply (subst mask_out_add_aligned[symmetric])
         apply (erule is_aligned_weaken)
         apply (simp add: pdBits_def pageBits_def)+
        done
      have eq_trans: "\<And>a b c d f. (c = d) \<Longrightarrow> (a = f c) \<Longrightarrow> (b = f d) \<Longrightarrow> (a = b)"
        by auto
      have mask_sub_mask:"\<And>m n x. ((x::word32) && mask n) && ~~ mask m = (x && ~~ mask m ) && mask n"
        by (rule word_eqI, auto)

  show ?thesis
  apply (clarsimp simp:valid_def)
  apply (subst vs_valid_duplicates'_def)
  apply (clarsimp split:option.splits)
  apply (drule copyGlobalMappings_ksPSpace_concrete)
     apply simp+
  apply (intro conjI)
   apply clarsimp
   apply (frule_tac ptr = ptr in globalPDEWindow_neg_mask)
     apply simp
    apply simp
   apply (clarsimp split:if_splits)
   apply (drule_tac p' = "((y && mask pdBits) + armKSGlobalPD (ksArchState s))" 
     in valid_duplicates'_D[rotated])
      apply (erule aligned_add_aligned[OF is_aligned_andI1])
       apply (erule is_aligned_weaken[where y = 2])
       apply (simp add:pdBits_def)
      apply simp
     apply (frule_tac x = "x && mask pdBits" and a = x2 and ptr = "armKSGlobalPD (ksArchState s)"
         in neg_mask_simp)
     apply (drule_tac x = "y && mask pdBits" and a = x2 and ptr = "armKSGlobalPD (ksArchState s)"
       in neg_mask_simp)
     apply (simp add:mask_sub_mask)
    apply simp
   apply simp
  apply (clarsimp split:if_splits)
   apply (drule_tac ptr = ptr in globalPDEWindow_neg_mask[OF sym])
     apply simp
    apply simp
   apply simp
  apply (drule_tac p' = y 
    in valid_duplicates'_D[rotated])
  apply simp+
  done
qed

lemma foldr_data_map_insert[simp]: 
 "foldr (\<lambda>addr map a. if a = addr then Some b else map a)
 = foldr (\<lambda>addr. data_map_insert addr b)"
  apply (rule ext)+
  apply (simp add:data_map_insert_def[abs_def] fun_upd_def)
  done

lemma new_cap_addrs_same_align_pdpt_bits:
assumes inset: "p\<in>set (new_cap_addrs (2 ^ us) ptr ko)"
  and   lowbound: "vs_entry_align ko \<le> us" 
  and   pdpt_align:"p && ~~ mask (vs_ptr_align ko) = p' && ~~ mask (vs_ptr_align ko)"
shows
    "\<lbrakk>is_aligned ptr (objBitsKO ko + us); us < 30;is_aligned p' 2\<rbrakk>
  \<Longrightarrow> p' \<in> set (new_cap_addrs (2 ^ us) ptr ko)"
  apply (subgoal_tac "\<And>x. \<lbrakk>is_aligned ptr (Suc (Suc us)); us < 30; is_aligned p' 2; 4 \<le> us; ptr + (of_nat x << 2) && ~~ mask 6 = p' && ~~ mask 6;
         x < 2 ^ us\<rbrakk>
        \<Longrightarrow> \<exists>x\<in>{0..<2 ^ us}. p' = ptr + (of_nat x << 2)")
   prefer 2
   using lowbound inset
   apply -
   apply (drule mask_out_first_mask_some[where m = "us + 2"])
    apply (simp add:mask_lower_twice)+
   apply (subst (asm) is_aligned_add_helper[THEN conjunct2])
     apply simp
    apply (rule shiftl_less_t2n)
     apply (simp add:of_nat_power)
    apply simp
   apply (rule_tac x= "unat (p' && mask (Suc (Suc us)) >> 2) " in bexI)
    apply simp
    apply (subst shiftr_shiftl1)
     apply simp+
    apply (subst is_aligned_neg_mask_eq[where n = 2]) 
     apply (erule is_aligned_andI1)
    apply (simp add:mask_out_sub_mask)
   apply simp
   apply (rule unat_less_power)
    apply (simp add:word_bits_def)
   apply (rule shiftr_less_t2n)
   apply (rule le_less_trans[OF word_and_le1])
   apply (rule less_le_trans[OF mask_lt_2pn])
    apply simp
   apply simp
  using pdpt_align
  apply (clarsimp simp: image_def vs_entry_align_def vs_ptr_align_def
    new_cap_addrs_def objBits_simps archObjSize_def
    split:Hardware_H.pde.splits Hardware_H.pte.splits arch_kernel_object.splits
    Structures_H.kernel_object.splits)
  done

lemma in_new_cap_addrs_aligned:
  "is_aligned ptr 2 \<Longrightarrow> p \<in> set (new_cap_addrs (2 ^ us) ptr ko) \<Longrightarrow> is_aligned p 2"
  apply (clarsimp simp:new_cap_addrs_def image_def)
  apply (erule aligned_add_aligned)
    apply (rule is_aligned_weaken[OF is_aligned_shiftl_self])
    apply (case_tac ko,simp_all add:objBits_simps word_bits_def
       pageBits_def archObjSize_def split:arch_kernel_object.splits)
  done

lemma valid_duplicates'_insert_ko:
  "\<lbrakk> vs_valid_duplicates' m; is_aligned ptr (objBitsKO ko + us);
    vs_entry_align ko \<le> us;
    objBitsKO ko + us < 32;
    \<forall>x\<in> set (new_cap_addrs (2^us) ptr ko). m x = None \<rbrakk>
  \<Longrightarrow>  vs_valid_duplicates'
  (foldr (\<lambda>addr. data_map_insert addr ko) (new_cap_addrs (2^us) ptr ko) m)"
  apply (subst vs_valid_duplicates'_def)
  apply (clarsimp simp: vs_entry_align_def
                        foldr_upd_app_if[folded data_map_insert_def])
  apply (clarsimp split:option.splits 
         simp:foldr_upd_app_if[unfolded data_map_insert_def[symmetric]])
  apply (rule conjI)
   apply clarsimp
   apply (case_tac ko, simp_all add:vs_ptr_align_def)
   apply (case_tac arch_kernel_object, simp_all split: Hardware_H.pte.splits)
    apply (drule(1) bspec)+
    apply (drule_tac p' = y in new_cap_addrs_same_align_pdpt_bits)
         apply (simp add:vs_entry_align_def)
        apply (simp add:vs_ptr_align_def)
       apply (simp add:objBits_simps archObjSize_def)+
   apply (clarsimp split: Hardware_H.pde.splits simp:objBits_simps)
   apply (drule(1) bspec)+
   apply (drule_tac p' = y in new_cap_addrs_same_align_pdpt_bits)
        apply (simp add:vs_entry_align_def)
       apply (simp add:vs_ptr_align_def)
      apply (simp add:objBits_simps archObjSize_def)+
  apply clarsimp
  apply (intro conjI impI allI)
   apply (drule(1) valid_duplicates'_D)
     apply fastforce
    apply (simp add:vs_ptr_align_def)
   apply simp
  apply (drule(2) valid_duplicates'_D)
      apply (clarsimp simp:vs_ptr_align_def
     split: Structures_H.kernel_object.splits
     Hardware_H.pde.splits Hardware_H.pte.splits
     arch_kernel_object.splits)
  apply simp
  done

lemma none_in_new_cap_addrs:
  "\<lbrakk>is_aligned ptr (objBitsKO obj + us); objBitsKO obj + us < word_bits;
  pspace_no_overlap' ptr (objBitsKO obj + us) s;
  pspace_aligned' s\<rbrakk>
  \<Longrightarrow> \<forall>x\<in>set (new_cap_addrs (2^us) ptr obj). ksPSpace s x = None"
  apply (rule ccontr,clarsimp)
  apply (drule not_in_new_cap_addrs[rotated - 1])
   apply simp+
  done

lemma valid_duplicates'_update:
  "\<lbrakk>is_aligned ptr (APIType_capBits ty us);pspace_aligned' s; 
   vs_valid_duplicates' (ksPSpace s); vs_entry_align ko = 0;
   pspace_no_overlap' ptr (APIType_capBits ty us) s\<rbrakk> \<Longrightarrow> vs_valid_duplicates'
   (\<lambda>a. if a = ptr then Some ko else ksPSpace s a)"
  apply (subst vs_valid_duplicates'_def)
  apply clarsimp
  apply (intro conjI impI allI)
    apply (case_tac ko,
           simp_all add: vs_ptr_align_def vs_entry_align_def)
    apply (case_tac arch_kernel_object,
           simp_all split: Hardware_H.pde.splits Hardware_H.pte.splits)
   apply (clarsimp split:option.splits)
   apply (drule(2) pspace_no_overlap_base')
   apply (drule(2) valid_duplicates'_D)
    apply simp
   apply (clarsimp split: option.splits)+
  apply (drule valid_duplicates'_D)
   apply simp+
  done

lemma createObject_valid_duplicates'[wp]:
  "\<lbrace>(\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and pspace_aligned' and pspace_distinct'
   and pspace_no_overlap' ptr (Types_H.getObjectSize ty us)
   and (\<lambda>s. is_aligned (armKSGlobalPD (ksArchState s)) pdBits)
   and K (is_aligned ptr (Types_H.getObjectSize ty us)) 
   and K (ty = APIObjectType ArchTypes_H.apiobject_type.CapTableObject \<longrightarrow> us < 28)\<rbrace>
  RetypeDecls_H.createObject ty ptr us 
  \<lbrace>\<lambda>xa s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (simp add:createObject_def) 
  apply (rule hoare_pre)
  apply (wpc | wp| simp add:ArchRetype_H.createObject_def)+
         apply (simp add:createPageObject_def placeNewObject_def
           placeNewObject'_def split_def 
           | wp hoare_unless_wp[where Q = \<top>]
           |wpc|simp add: alignError_def)+
     apply (rule copyGlobalMappings_valid_duplicates')
    apply ((wp hoare_unless_wp[where Q = \<top>]|wpc
     |simp add:alignError_def placeNewObject_def 
      placeNewObject'_def split_def)+)[2]
  apply (intro conjI impI)
         apply simp
        apply clarsimp
        apply (erule(2) valid_duplicates'_update)
         apply (clarsimp simp: vs_entry_align_def)
        apply simp
       apply (clarsimp simp:new_cap_addrs_fold'[where n = "0x10",simplified])
       apply (erule valid_duplicates'_insert_ko[where us = 4,simplified])
         apply (simp add: Types_H.toAPIType_def vs_entry_align_def
                          APIType_capBits_def objBits_simps pageBits_def)+
       apply (rule none_in_new_cap_addrs[where us = 4,simplified]
          ,(simp add:objBits_simps pageBits_def word_bits_conv)+)[1]
      apply (clarsimp simp:new_cap_addrs_fold'[where n = "0x100",simplified])
      apply (erule valid_duplicates'_insert_ko[where us = 8,simplified])
         apply (simp add: Types_H.toAPIType_def vs_entry_align_def
                          APIType_capBits_def objBits_simps pageBits_def)+
      apply (rule none_in_new_cap_addrs[where us =8,simplified]
        ,(simp add:objBits_simps pageBits_def word_bits_conv)+)[1]
     apply (clarsimp simp:new_cap_addrs_fold'[where n = "0x1000",simplified])
     apply (erule valid_duplicates'_insert_ko[where us = 12,simplified])
        apply (simp add: Types_H.toAPIType_def vs_entry_align_def
                         APIType_capBits_def objBits_simps pageBits_def)+
     apply (rule none_in_new_cap_addrs[where us =12,simplified]
       ,(simp add:objBits_simps pageBits_def word_bits_conv)+)[1]
    apply (clarsimp simp:objBits_simps ptBits_def archObjSize_def pageBits_def)
    apply (cut_tac ptr=ptr in new_cap_addrs_fold'[where n = "0x100" and ko = "(KOArch (KOPTE makeObject))"
      ,simplified objBits_simps])
     apply simp
    apply (clarsimp simp:archObjSize_def)
    apply (erule valid_duplicates'_insert_ko[where us = 8,simplified])
       apply (simp add: Types_H.toAPIType_def archObjSize_def vs_entry_align_def
                        APIType_capBits_def objBits_simps pageBits_def
                 split: Hardware_H.pte.splits)+
    apply (rule none_in_new_cap_addrs[where us =8,simplified]
      ,(simp add:objBits_simps pageBits_def word_bits_conv archObjSize_def)+)[1]
   apply clarsimp
   apply (cut_tac ptr=ptr in new_cap_addrs_fold'[where n = "0x1000" and ko = "(KOArch (KOPDE makeObject))"
     ,simplified objBits_simps])
     apply simp
   apply (clarsimp simp:objBits_simps archObjSize_def pdBits_def pageBits_def)
   apply (frule(2) retype_aligned_distinct'[where n = 4096 and ko = "KOArch (KOPDE makeObject)"])
    apply (simp add:objBits_simps archObjSize_def)
    apply (rule range_cover_rel[OF range_cover_full])
       apply simp
      apply (simp add:APIType_capBits_def word_bits_def)+
   apply (frule(2) retype_aligned_distinct'(2)[where n = 4096 and ko = "KOArch (KOPDE makeObject)"])
    apply (simp add:objBits_simps archObjSize_def)
    apply (rule range_cover_rel[OF range_cover_full])
       apply simp
      apply (simp add:APIType_capBits_def word_bits_def)+
   apply (subgoal_tac "vs_valid_duplicates'
                 (foldr (\<lambda>addr. data_map_insert addr (KOArch (KOPDE makeObject)))
                   (map (\<lambda>n. ptr + (n << 2)) [0.e.2 ^ (pdBits - 2) - 1]) (ksPSpace s))")
    apply (simp add:APIType_capBits_def pdBits_def pageBits_def 
      data_map_insert_def[abs_def])
   apply (clarsimp simp:archObjSize_def pdBits_def pageBits_def)
   apply (rule valid_duplicates'_insert_ko[where us = 12,simplified])
       apply (simp add: Types_H.toAPIType_def archObjSize_def vs_entry_align_def
                        APIType_capBits_def objBits_simps pageBits_def 
                 split: Hardware_H.pde.splits)+
   apply (rule none_in_new_cap_addrs[where us =12,simplified]
     ,(simp add:objBits_simps pageBits_def word_bits_conv archObjSize_def)+)[1]
  apply (intro conjI impI allI)
      apply simp
     apply clarsimp
     apply (drule(2) valid_duplicates'_update) prefer 3
       apply fastforce
      apply (simp add: vs_entry_align_def)
     apply simp
    apply clarsimp
    apply (drule(2) valid_duplicates'_update) prefer 3
      apply (fastforce simp: vs_entry_align_def)+
   apply clarsimp
   apply (drule(2) valid_duplicates'_update) prefer 3
     apply (fastforce simp: vs_entry_align_def)+
  apply (clarsimp simp:Types_H.toAPIType_def word_bits_def
    ArchTypes_H.toAPIType_def split:ArchTypes_H.object_type.splits)
  apply (cut_tac ptr = ptr in new_cap_addrs_fold'[where n = "2^us" 
    and ko = "(KOCTE makeObject)",simplified])
   apply (rule word_1_le_power)
  apply (clarsimp simp:word_bits_def)
  apply (drule_tac ptr = ptr and ko = "KOCTE makeObject" in
    valid_duplicates'_insert_ko[where us = us,simplified])
      apply (simp add:APIType_capBits_def is_aligned_mask
       Types_H.toAPIType_def ArchTypes_H.toAPIType_def
      split:ArchTypes_H.object_type.splits)
     apply (simp add:vs_entry_align_def)
    apply (simp add:objBits_simps)
   apply (rule none_in_new_cap_addrs
     ,(simp add:objBits_simps pageBits_def APIType_capBits_def 
     Types_H.toAPIType_def ArchTypes_H.toAPIType_def
     word_bits_conv archObjSize_def is_aligned_mask
     split:ArchTypes_H.object_type.splits)+)[1]
  apply (clarsimp simp:word_bits_def)
  done

crunch arch_inv[wp]: createNewObjects "\<lambda>s. P (armKSGlobalPD (ksArchState s))"
  (simp: crunch_simps zipWithM_x_mapM wp: crunch_wps hoare_unless_wp)

lemma createNewObjects_valid_duplicates'[wp]:
 "\<lbrace> (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and pspace_no_overlap' ptr sz
  and pspace_aligned' and pspace_distinct' and (\<lambda>s. is_aligned (armKSGlobalPD (ksArchState s)) pdBits)
  and K (range_cover ptr sz (Types_H.getObjectSize ty us) (length dest) \<and> 
      ptr \<noteq> 0 \<and> (ty = APIObjectType ArchTypes_H.apiobject_type.CapTableObject \<longrightarrow> us < 28) ) \<rbrace>
       createNewObjects ty src dest ptr us 
  \<lbrace>\<lambda>reply s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  proof (induct rule:rev_induct )
    case Nil
    show ?case
      by (simp add:createNewObjects_def zipWithM_x_mapM mapM_Nil | wp)+
   next
   case (snoc dest dests)
   show ?case
     apply (rule hoare_gen_asm)
     apply clarsimp
     apply (frule range_cover.weak)
     apply (subst createNewObjects_Cons)
      apply (simp add: word_bits_def)
     apply wp
     apply (rule hoare_pre)
      apply (wp snoc.hyps)
      apply (rule hoare_vcg_conj_lift)
       apply (rule hoare_post_imp[OF _ createNewObjects_pspace_no_overlap'[where sz = sz]])
       apply clarsimp
      apply (rule hoare_vcg_conj_lift)
       apply (rule hoare_post_imp[OF _ createNewObjects_pspace_no_overlap'[where sz = sz]])
       apply clarsimp
      apply (rule hoare_vcg_conj_lift)
       apply (rule hoare_post_imp[OF _ createNewObjects_pspace_no_overlap'[where sz = sz]])
       apply (rule pspace_no_overlap'_le)
        apply fastforce
       apply (simp add: range_cover.sz[where 'a=32, folded word_bits_def])+
      apply wp
     apply clarsimp
     apply (frule range_cover.aligned)
     apply (intro conjI aligned_add_aligned)
        apply (erule range_cover_le,simp)
       apply (rule is_aligned_shiftl_self)
      apply simp
     apply simp
     done
   qed

lemma valid_duplicates'_diffI:
  defines "heap_diff m m' \<equiv> {(x::word32). (m x \<noteq> m' x)}"
  shows "\<lbrakk>vs_valid_duplicates' m;
          vs_valid_duplicates' (\<lambda>x. if x \<in> (heap_diff m m') then m' x else None);
          vs_valid_duplicates' (\<lambda>x. if x \<in> (heap_diff m m') then None else m' x)\<rbrakk>
         \<Longrightarrow> vs_valid_duplicates' m'"
  apply (subst vs_valid_duplicates'_def)
  apply (clarsimp simp: heap_diff_def split: option.splits)
  apply (case_tac "m x = m' x")
   apply simp
   apply (case_tac "m y = m' y")
    apply (drule(2) valid_duplicates'_D)
    apply simp+
   apply (drule(2) valid_duplicates'_D)
   apply (thin_tac "vs_valid_duplicates' ?m")
   apply (drule_tac p = x and ko = "the (m' x)" in valid_duplicates'_D)
      apply (clarsimp split:if_splits)
     apply assumption
    apply (clarsimp split:if_splits)+
   apply (case_tac "m y = m' y")
    apply clarsimp
   apply (thin_tac "vs_valid_duplicates' ?m")
   apply (drule_tac p = x and ko = "the (m' x)" in valid_duplicates'_D)
      apply (clarsimp split:if_splits)
     apply assumption
    apply (simp split:if_splits)+
  apply (thin_tac "vs_valid_duplicates' ?m")
  apply (drule_tac p = x and ko = "the (m' x)" in valid_duplicates'_D)
   apply (clarsimp split:if_splits)
    apply assumption
   apply (clarsimp split:if_splits)+
  done

lemma valid_duplicates_deleteObjects_helper:
  assumes vd:"vs_valid_duplicates' (m::(word32 \<rightharpoonup> Structures_H.kernel_object))"
  assumes inc: "\<And>p ko. \<lbrakk>m p = Some (KOArch ko);p \<in> {ptr .. ptr + 2 ^ sz - 1}\<rbrakk>
  \<Longrightarrow> 6 \<le> sz"
  assumes aligned:"is_aligned ptr sz"
  notes blah[simp del] =  atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex
          atLeastAtMost_iff
  shows "vs_valid_duplicates'  (\<lambda>x. if x \<in> {ptr .. ptr + 2 ^ sz - 1} then None else m x)"
  apply (rule valid_duplicates'_diffI,rule vd)
  apply (clarsimp simp: vs_valid_duplicates'_def split:option.splits)
  apply (clarsimp simp: vs_valid_duplicates'_def split:option.splits)
  apply (case_tac "the (m x)",simp_all add:vs_ptr_align_def)
   apply fastforce+
  apply (case_tac arch_kernel_object)
    apply fastforce+
   apply (clarsimp split:Hardware_H.pte.splits)
   apply auto[1]
     apply (drule_tac p' = y in valid_duplicates'_D[OF vd])
       apply (simp add:vs_ptr_align_def)+
     apply clarsimp
     apply (drule(1) inc)
     apply (drule(1) mask_out_first_mask_some)
      apply (simp add:mask_lower_twice)
     apply (simp add: mask_in_range[OF aligned,symmetric])
    apply (drule_tac p' = y in valid_duplicates'_D[OF vd]) 
      apply simp
     apply (simp add:vs_ptr_align_def)
    apply simp
   apply (drule_tac p' = y in valid_duplicates'_D[OF vd]) 
     apply simp
    apply (simp add:vs_ptr_align_def)
   apply simp
  apply (clarsimp split:Hardware_H.pde.splits)
  apply auto[1]
    apply (drule_tac p' = y in valid_duplicates'_D[OF vd])
      apply simp
     apply (simp add:vs_ptr_align_def)
    apply (drule(1) inc)
    apply (drule(1) mask_out_first_mask_some)
    apply (simp add:mask_lower_twice)
    apply (simp add: mask_in_range[OF aligned,symmetric])
   apply (drule_tac p' = y in valid_duplicates'_D[OF vd])
     apply simp
    apply (simp add:vs_ptr_align_def)
   apply simp
  apply (drule_tac p' = y in valid_duplicates'_D[OF vd])
    apply simp
   apply (simp add:vs_ptr_align_def)
  apply simp
  done

lemma deleteObjects_valid_duplicates'[wp]:
  notes blah[simp del] =  atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex
          atLeastAtMost_iff
  shows
  "\<lbrace>(\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and 
      K (is_aligned ptr sz)
   \<rbrace> deleteObjects ptr sz
   \<lbrace>\<lambda>r s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (clarsimp simp:deleteObjects_def2)
  apply (wp|simp)+
  apply clarsimp
  apply (simp add:deletionIsSafe_def)
  apply (erule valid_duplicates_deleteObjects_helper)
   apply fastforce
  apply simp
  done

crunch arch_inv[wp]: deleteObjects "\<lambda>s. P (ksArchState s)"
  (simp: crunch_simps wp: hoare_drop_imps hoare_unless_wp ignore:freeMemory)

lemma invokeUntyped_valid_duplicates[wp]:
  "\<lbrace>invs' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s))
         and valid_untyped_inv' ui and ct_active'\<rbrace>
     invokeUntyped ui
   \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s) \<rbrace>"
  apply (rule hoare_name_pre_state)
  apply (cases ui)
  apply (clarsimp)
  apply (rename_tac s cref ptr tp us slots sz idx)
proof -
 fix s cref ptr tp us slots sz idx
    assume cte_wp_at': "cte_wp_at' (\<lambda>cte. cteCap cte = capability.UntypedCap (ptr && ~~ mask sz) sz idx) cref s"
    assume cover     : "range_cover ptr sz (APIType_capBits tp us) (length (slots::word32 list))"
    assume  misc     : "distinct slots" "idx \<le> unat (ptr && mask sz) \<or> ptr = ptr && ~~ mask sz"
      "invs' s" "slots \<noteq> []" "sch_act_simple s" "vs_valid_duplicates' (ksPSpace s)"
      "\<forall>slot\<in>set slots. cte_wp_at' (\<lambda>c. cteCap c = capability.NullCap) slot s"
      "\<forall>x\<in>set slots. ex_cte_cap_wp_to' (\<lambda>_. True) x s"  "ct_active' s"
      "tp = APIObjectType ArchTypes_H.apiobject_type.Untyped \<longrightarrow> 4 \<le> us \<and> us \<le> 30"
    assume desc_range: "ptr = ptr && ~~ mask sz \<longrightarrow> descendants_range_in' {ptr..ptr + 2 ^ sz - 1} (cref) (ctes_of s)"
    
  have pf: "invokeUntyped_proofs s cref ptr tp us slots sz idx"
    using cte_wp_at' cover misc desc_range
    by (simp add:invokeUntyped_proofs_def)
  have bound[simp]: "tp = APIObjectType ArchTypes_H.apiobject_type.CapTableObject \<longrightarrow> us < 28"
    using cover
    apply -
    apply (frule range_cover.sz)
    apply (drule range_cover.sz(2))
    apply (clarsimp simp:APIType_capBits_def objBits_simps word_bits_def)
    done
  have pd_aligned[simp]:
    "armKSGlobalPD (ksArchState s) && ~~ mask pdBits = armKSGlobalPD (ksArchState s)"
    using misc
    apply -
    apply (clarsimp dest!:invs_arch_state' simp:valid_arch_state'_def
      page_directory_at'_def is_aligned_neg_mask_eq')
    done
  show 
  "\<lbrace>op = s\<rbrace>
    invokeUntyped
    (Invocations_H.untyped_invocation.Retype cref (ptr && ~~ mask sz) ptr tp us slots) 
    \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (clarsimp simp:invokeUntyped_def updateCap_def)
  apply (rule hoare_pre)
   apply (wp setCTE_pspace_no_overlap'[where sz = sz ]
     deleteObjects_invs_derivatives[where idx = idx and p = cref])
    apply (rule_tac P = "cap = capability.UntypedCap (ptr && ~~ mask sz) sz idx" 
       in hoare_gen_asm)
    apply simp
    apply (wp getSlotCap_wp 
      deleteObject_no_overlap deleteObjects_invs_derivatives[where idx = idx and p = cref])
  using cte_wp_at' misc cover desc_range 
        invokeUntyped_proofs.not_0_ptr[OF pf] invokeUntyped_proofs.vc'[OF pf]
  apply (clarsimp simp:cte_wp_at_ctes_of)
  apply (rule_tac x = "capability.UntypedCap (ptr && ~~ mask sz) sz idx" in exI)
  apply (clarsimp simp: is_aligned_neg_mask_eq' conj_ac invs_valid_pspace'
             invs_pspace_aligned' invs_pspace_distinct'
             range_cover.sz[where 'a=32, folded word_bits_def]
             invokeUntyped_proofs.ps_no_overlap'[OF pf])
  apply (simp add:descendants_range'_def2)
  done
  qed

crunch valid_duplicates'[wp]:
  sendAsyncIPC "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"

crunch valid_duplicates'[wp]:
  doReplyTransfer "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(wp: crunch_wps isFinalCapability_inv 
 simp: crunch_simps unless_def)

crunch valid_duplicates'[wp]:
  setVMRoot "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(wp: crunch_wps simp: crunch_simps unless_def)

crunch valid_duplicates'[wp]:
  invalidateASIDEntry "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(wp: crunch_wps simp: crunch_simps unless_def)

crunch valid_duplicates'[wp]:
  flushSpace "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
(wp: crunch_wps simp: crunch_simps unless_def)

lemma get_asid_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace> 
  getObject param_b \<lbrace>\<lambda>(pool::asidpool) s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:getObject_def split_def| wp)+
  apply (simp add:loadObject_default_def|wp)+
  done

lemma set_asid_pool_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
  setObject a (pool::asidpool)
  \<lbrace>\<lambda>r s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (clarsimp simp: setObject_def split_def valid_def in_monad
                        projectKOs pspace_aligned'_def ps_clear_upd'
                        objBits_def[symmetric] lookupAround2_char1
                 split: split_if_asm)
  apply (frule pspace_storable_class.updateObject_type[where v = pool,simplified])
  apply (clarsimp simp:updateObject_default_def assert_def bind_def 
    alignCheck_def in_monad when_def alignError_def magnitudeCheck_def
    assert_opt_def return_def fail_def typeError_def
    split:if_splits option.splits Structures_H.kernel_object.splits)
     apply (erule valid_duplicates'_non_pd_pt_I[rotated 3],clarsimp+)+
  done

crunch valid_duplicates'[wp]:
  suspend "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps simp: crunch_simps unless_def)

crunch valid_duplicates'[wp]:
deletingIRQHandler  "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps simp: crunch_simps unless_def)

lemma storePDE_no_duplicates':
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s) 
    \<and> ko_wp_at' (\<lambda>ko. vs_entry_align ko = 0 ) ptr s
    \<and> vs_entry_align (KOArch (KOPDE pde)) = 0 \<rbrace>
   storePDE ptr pde 
  \<lbrace>\<lambda>ya s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:storePDE_def setObject_def split_def | wp | wpc)+
    apply (simp add:updateObject_default_def)
    apply wp
  apply clarsimp
  apply (subst vs_valid_duplicates'_def)
   apply clarsimp
  apply (intro conjI impI)
   apply (clarsimp simp:vs_ptr_align_def vs_entry_align_def
     split:option.splits
     Hardware_H.pde.splits)
  apply clarsimp
  apply (intro conjI impI)
   apply (clarsimp split:option.splits)
   apply (drule_tac p = x in valid_duplicates'_D)
      apply simp
     apply simp
    apply simp
   apply (clarsimp simp:ko_wp_at'_def vs_entry_align_def
     vs_ptr_align_def
     split:if_splits option.splits arch_kernel_object.splits
     Structures_H.kernel_object.splits Hardware_H.pde.splits
     Hardware_H.pte.splits)
  apply (clarsimp split:option.splits)
  apply (drule_tac p = x and p' = y in valid_duplicates'_D)
   apply simp+
  done

lemma storePTE_no_duplicates':
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s) 
    \<and> ko_wp_at' (\<lambda>ko. vs_entry_align ko = 0 ) ptr s
    \<and> vs_entry_align (KOArch (KOPTE pte)) = 0 \<rbrace>
   storePTE ptr pte 
  \<lbrace>\<lambda>ya s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:storePTE_def setObject_def split_def | wp | wpc)+
    apply (simp add:updateObject_default_def)
    apply wp
  apply clarsimp
  apply (subst vs_valid_duplicates'_def)
   apply clarsimp
  apply (intro conjI impI)
   apply (clarsimp simp:vs_entry_align_def vs_ptr_align_def
     split:option.splits
     Hardware_H.pte.splits)
  apply clarsimp
  apply (intro conjI impI)
   apply (clarsimp split:option.splits)
   apply (drule_tac p = x in valid_duplicates'_D)
      apply simp
     apply simp
    apply simp
   apply (clarsimp simp:ko_wp_at'_def
     vs_ptr_align_def vs_entry_align_def
     split:if_splits option.splits arch_kernel_object.splits
     Structures_H.kernel_object.splits Hardware_H.pde.splits
     Hardware_H.pte.splits)
  apply (clarsimp split:option.splits)
  apply (drule_tac p = x and p' = y in valid_duplicates'_D)
   apply simp+
  done

crunch valid_duplicates'[wp]:
 lookupPTSlot "\<lambda>s. valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps simp: crunch_simps unless_def
    ignore:getObject updateObject setObject)

lemma checkMappingPPtr_SmallPage:
  "\<lbrace>\<top>\<rbrace> checkMappingPPtr word ARMSmallPage (Inl p) 
           \<lbrace>\<lambda>x s. ko_wp_at' (\<lambda>ko. vs_entry_align ko = 0) p s\<rbrace>,-"
  apply (simp add:checkMappingPPtr_def)
   apply (wp unlessE_wp getPTE_wp |wpc|simp add:)+
  apply (clarsimp simp:ko_wp_at'_def obj_at'_def)
  apply (clarsimp simp:projectKO_def projectKO_opt_pte
    return_def fail_def vs_entry_align_def
    split:kernel_object.splits 
    arch_kernel_object.splits option.splits)
  done

lemma checkMappingPPtr_Section:
  "\<lbrace>\<top>\<rbrace> checkMappingPPtr word ARMSection (Inr p) 
           \<lbrace>\<lambda>x s. ko_wp_at' (\<lambda>ko. vs_entry_align ko = 0) p s\<rbrace>,-"
  apply (simp add:checkMappingPPtr_def)
   apply (wp unlessE_wp getPDE_wp |wpc|simp add:)+
  apply (clarsimp simp:ko_wp_at'_def obj_at'_def)
  apply (clarsimp simp:projectKO_def projectKO_opt_pde
    return_def fail_def vs_entry_align_def
    split:kernel_object.splits 
    arch_kernel_object.splits option.splits)
  done

lemma mapM_x_mapM_valid:
  "\<lbrace> P \<rbrace> mapM_x f xs \<lbrace>\<lambda>r. Q\<rbrace> \<Longrightarrow> \<lbrace>P\<rbrace>mapM f xs \<lbrace>\<lambda>r. Q\<rbrace>"
  apply (simp add:NonDetMonadLemmaBucket.mapM_x_mapM)
  apply (clarsimp simp:valid_def return_def bind_def)
  apply (drule spec)
  apply (erule impE)
   apply simp
  apply (drule(1) bspec)
  apply fastforce
  done

crunch valid_duplicates'[wp]:
 flushPage "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps simp: crunch_simps unless_def
    ignore:getObject updateObject setObject)

crunch valid_duplicates'[wp]:
 findPDForASID "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps simp: crunch_simps unless_def
    ignore:getObject updateObject setObject)

lemma lookupPTSlot_aligned:
  "\<lbrace>\<lambda>s. valid_objs' s \<and> vmsz_aligned' vptr sz \<and> sz \<noteq> ARMSuperSection\<rbrace>
   lookupPTSlot pd vptr 
  \<lbrace>\<lambda>rv s. is_aligned rv ((pageBitsForSize sz) - 10)\<rbrace>,-"
  apply (simp add:lookupPTSlot_def)
  apply (wp|wpc|simp)+
  apply (wp getPDE_wp)
  apply (clarsimp simp:obj_at'_def vmsz_aligned'_def)
  apply (clarsimp simp:projectKO_def fail_def 
    projectKO_opt_pde return_def
    split:option.splits Structures_H.kernel_object.splits
    arch_kernel_object.splits)
  apply (erule(1) valid_objsE')
  apply (rule aligned_add_aligned)
     apply (simp add:valid_obj'_def)
     apply (erule is_aligned_ptrFromPAddr_n)
     apply (simp add:ptBits_def pageBits_def)
    apply (rule is_aligned_shiftl)
    apply (rule is_aligned_andI1)
    apply (rule is_aligned_shiftr)
    apply (case_tac sz,simp_all)[1]
   apply (simp add:ptBits_def word_bits_def pageBits_def)
  apply (case_tac sz,simp_all add:ptBits_def pageBits_def)
  done

crunch valid_arch_state'[wp]:
 flushPage valid_arch_state'
  (wp: crunch_wps simp: crunch_simps unless_def
    ignore:getObject updateObject setObject)

crunch valid_arch_state'[wp]:
 flushTable "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps simp: crunch_simps unless_def
    ignore:getObject updateObject setObject)

lemma unmapPage_valid_duplicates'[wp]:
  notes checkMappingPPtr_inv[wp del] shows
  "\<lbrace>pspace_aligned' and valid_objs' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) 
   and K (vmsz_aligned' vptr vmpage_size)\<rbrace>
  unmapPage vmpage_size asiv vptr word \<lbrace>\<lambda>r s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:unmapPage_def)
   (* make sure checkMappingPPtr_SmallPage is first tried before checkMappingPPtr_inv *)
  apply (wp storePTE_no_duplicates' mapM_x_mapM_valid
    storePDE_no_duplicates' checkMappingPPtr_Section
    mapM_x_storePDE_update_helper[where sz = 6]
    lookupPTSlot_page_table_at'
    checkMappingPPtr_SmallPage | wpc  
    | simp add:split_def conj_ac | wp_once checkMappingPPtr_inv)+
          apply (rule_tac ptr = "p && ~~ mask ptBits" and word = p
            in mapM_x_storePTE_update_helper[where sz = 6])
         apply simp
         apply (wp mapM_x_mapM_valid)
         apply (rule_tac ptr = "p && ~~ mask ptBits" and word = p
           in mapM_x_storePTE_update_helper[where sz = 6])
        apply simp
        apply wp
       apply clarsimp
       apply (wp checkMappingPPtr_inv lookupPTSlot_page_table_at')
      apply (rule hoare_post_imp_R[OF lookupPTSlot_aligned[where sz= vmpage_size]])
      apply (simp add:pageBitsForSize_def)
      apply (drule upto_enum_step_shift[where n = 6 and m = 2,simplified])
      apply (clarsimp simp:mask_def add.commute upto_enum_step_def)
     apply wp
        apply (wp storePTE_no_duplicates' mapM_x_mapM_valid
          storePDE_no_duplicates' checkMappingPPtr_Section
          checkMappingPPtr_SmallPage | wpc  
          | simp add:split_def conj_ac | wp_once checkMappingPPtr_inv)+
        apply (rule_tac ptr = "p && ~~ mask pdBits" and word = p
          in mapM_x_storePDE_update_helper[where sz = 6])
       apply (wp mapM_x_mapM_valid)
       apply (rule_tac ptr = "p && ~~ mask pdBits" and word = p
         in mapM_x_storePDE_update_helper[where sz = 6])
      apply wp
     apply (clarsimp simp:conj_ac)
  apply (wp checkMappingPPtr_inv static_imp_wp)
  apply (clarsimp simp:conj_ac)
  apply (rule hoare_pre)
   apply (wp)
   apply (rule hoare_post_imp_R[where Q'= "\<lambda>r. pspace_aligned' and 
     (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and 
     K(vmsz_aligned' vptr vmpage_size \<and> is_aligned r pdBits)
     and page_directory_at' (lookup_pd_slot r vptr && ~~ mask pdBits)"])
    apply (wp findPDForASID_page_directory_at' | simp)+
   apply (clarsimp simp add:pdBits_def pageBits_def vmsz_aligned'_def)
   apply (drule is_aligned_lookup_pd_slot)
    apply (erule is_aligned_weaken,simp)
   apply simp
   apply (drule upto_enum_step_shift[where n = 6 and m = 2,simplified])
   apply (clarsimp simp:mask_def add.commute upto_enum_step_def)
  apply (clarsimp simp:ptBits_def pageBits_def vs_entry_align_def)
  done

crunch ko_wp_at'[wp]:
 checkPDNotInASIDMap "\<lambda>s. ko_wp_at' P p s"
  (wp: crunch_wps simp: crunch_simps unless_def
    ignore:getObject updateObject setObject)

crunch ko_wp_at'[wp]:
 setCurrentASID "\<lambda>s. ko_wp_at' P p s"
  (wp: crunch_wps simp: crunch_simps unless_def
    ignore:getObject updateObject setObject)

lemma setVMRoot_vs_entry_align[wp]:
  "\<lbrace>ko_wp_at' (\<lambda>ko. P (vs_entry_align ko)) p \<rbrace> setVMRoot x 
  \<lbrace>\<lambda>rv. ko_wp_at' (\<lambda>ko. P (vs_entry_align ko)) p\<rbrace>"
  apply (simp add:setVMRoot_def armv_contextSwitch_def)
  apply (wp whenE_inv hoare_drop_imp |wpc|simp add: armv_contextSwitch_def)+
   apply (rule hoare_post_imp[where Q = "\<lambda>r. ko_wp_at' (\<lambda>a. P (vs_entry_align a)) p"])
    apply (simp)
   apply (wp|simp)+
  apply (simp add:getThreadVSpaceRoot_def locateSlot_def)
  done

crunch ko_wp_at'[wp]:
 setVMRootForFlush "\<lambda>s. ko_wp_at' P p s"
  (wp: crunch_wps simp: crunch_simps unless_def
    ignore:getObject updateObject setObject)

lemma flushTable_vs_entry_align[wp]:
  "\<lbrace>ko_wp_at' (\<lambda>ko. P (vs_entry_align ko)) p\<rbrace> flushTable a aa ba
  \<lbrace>\<lambda>rv. ko_wp_at' (\<lambda>ko. P (vs_entry_align ko)) p \<rbrace>"
  apply (simp add:flushTable_def)
  apply (wp mapM_wp' | wpc | simp)+
  done

lemma unmapPageTable_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
    unmapPageTable aa ba word \<lbrace>\<lambda>x a. vs_valid_duplicates' (ksPSpace a)\<rbrace>"
  apply (rule hoare_pre)
   apply (simp add:unmapPageTable_def)
   apply (wp|wpc|simp)+
      apply (wp storePDE_no_duplicates')
   apply simp
  apply (simp add:pageTableMapped_def)
   apply (wp getPDE_wp |wpc|simp)+
   apply (rule hoare_post_imp_R[where Q' = "\<lambda>r s. vs_valid_duplicates' (ksPSpace s)"])
    apply wp
   apply (clarsimp simp:ko_wp_at'_def 
     obj_at'_real_def projectKO_opt_pde)
   apply (clarsimp simp:vs_entry_align_def
     split:arch_kernel_object.splits
     Hardware_H.pde.split Structures_H.kernel_object.splits)
  apply simp
  done

crunch valid_duplicates'[wp]:
 deleteASID "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps simp: crunch_simps unless_def
    ignore:getObject updateObject setObject)

crunch valid_duplicates'[wp]:
  deleteASIDPool "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps simp: crunch_simps unless_def ignore:getObject setObject)

lemma archFinaliseCap_valid_duplicates'[wp]:
  "\<lbrace>valid_objs' and pspace_aligned' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) 
    and (valid_cap' (capability.ArchObjectCap arch_cap))\<rbrace>
  ArchRetypeDecls_H.finaliseCap arch_cap is_final 
  \<lbrace>\<lambda>ya a. vs_valid_duplicates' (ksPSpace a)\<rbrace>"
  apply (case_tac arch_cap,simp_all add:ArchRetype_H.finaliseCap_def)
      apply (rule hoare_pre)
       apply (wp|wpc|simp)+
    apply (rule hoare_pre)
     apply (wp|wpc|simp)+
    apply (clarsimp simp:valid_cap'_def)
   apply (rule hoare_pre)
    apply (wp|wpc|simp)+
  apply (rule hoare_pre)
   apply (wp|wpc|simp)+
  done

lemma finaliseCap_valid_duplicates'[wp]:
  "\<lbrace>valid_objs' and pspace_aligned' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) 
  and (valid_cap' cap)\<rbrace>
  finaliseCap cap call final \<lbrace>\<lambda>r s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (case_tac cap,simp_all add:isCap_simps finaliseCap_def)
            apply (wp|intro conjI|clarsimp )+
  done

crunch valid_duplicates'[wp]:
  capSwapForDelete "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps simp: crunch_simps unless_def ignore:getObject setObject)

crunch valid_duplicates'[wp]:
  cteMove "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps simp: crunch_simps unless_def ignore:getObject setObject)

crunch valid_duplicates'[wp]:
  epCancelBadgedSends "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps filterM_preserved simp: crunch_simps unless_def 
    ignore:getObject setObject)

crunch valid_duplicates'[wp]:
  invalidateTLBByASID "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps filterM_preserved simp: crunch_simps unless_def 
    ignore:getObject setObject)

declare withoutPreemption_lift [wp del]

lemma reduceZombie_valid_duplicates_spec':
  assumes fin:
  "\<And>s'' rv. \<lbrakk>\<not> (isZombie cap \<and> capZombieNumber cap = 0); \<not> (isZombie cap \<and> \<not> exposed); isZombie cap \<and> exposed;
              (Inr rv, s'')
              \<in> fst ((withoutPreemption $ locateSlot (capZombiePtr cap) (fromIntegral (capZombieNumber cap - 1))) st)\<rbrakk>
             \<Longrightarrow> s'' \<turnstile> \<lbrace>\<lambda>s. invs' s \<and> (vs_valid_duplicates' (ksPSpace s)) \<and> sch_act_simple s
                                   \<and> cte_wp_at' (\<lambda>cte. isZombie (cteCap cte)) slot s
                                   \<and> ex_cte_cap_to' rv s\<rbrace>
                         finaliseSlot rv False
                \<lbrace>\<lambda>rva s. invs' s \<and> (vs_valid_duplicates' (ksPSpace s)) \<and> sch_act_simple s
                            \<and> (fst rva \<longrightarrow> cte_wp_at' (\<lambda>cte. removeable' rv s (cteCap cte)) rv s)
                            \<and> (\<forall>irq sl'. snd rva = Some irq \<longrightarrow> sl' \<noteq> rv \<longrightarrow> cteCaps_of s sl' \<noteq> Some (IRQHandlerCap irq))\<rbrace>,
                \<lbrace>\<lambda>rv s. invs' s \<and> (vs_valid_duplicates' (ksPSpace s)) \<and> sch_act_simple s\<rbrace>"
  shows
  "st \<turnstile> \<lbrace>\<lambda>s.
      invs' s \<and> vs_valid_duplicates' (ksPSpace s) \<and>sch_act_simple s
              \<and> (exposed \<or> ex_cte_cap_to' slot s)
              \<and> cte_wp_at' (\<lambda>cte. cteCap cte = cap) slot s
              \<and> (exposed \<or> p = slot \<or>
                  cte_wp_at' (\<lambda>cte. (P and isZombie) (cteCap cte)
                                  \<or> (\<exists>zb n cp. cteCap cte = Zombie p zb n
                                       \<and> P cp \<and> (isZombie cp \<longrightarrow> capZombiePtr cp \<noteq> p))) p s)\<rbrace>
       reduceZombie cap slot exposed
   \<lbrace>\<lambda>rv s.
      invs' s \<and> vs_valid_duplicates' (ksPSpace s) \<and> sch_act_simple s
              \<and> (exposed \<or> ex_cte_cap_to' slot s)
              \<and> (exposed \<or> p = slot \<or>
                  cte_wp_at' (\<lambda>cte. (P and isZombie) (cteCap cte)
                                  \<or> (\<exists>zb n cp. cteCap cte = Zombie p zb n
                                       \<and> P cp \<and> (isZombie cp \<longrightarrow> capZombiePtr cp \<noteq> p))) p s)\<rbrace>,
   \<lbrace>\<lambda>rv s. invs' s \<and> vs_valid_duplicates' (ksPSpace s) \<and> sch_act_simple s\<rbrace>"
  apply (unfold reduceZombie_def cteDelete_def Let_def
                split_def fst_conv snd_conv haskell_fail_def
                case_Zombie_assert_fold)
  apply (rule hoare_pre_spec_validE)
   apply (wp hoare_vcg_disj_lift | simp)+
       apply (wp capSwap_cte_wp_cteCap getCTE_wp' | simp)+
           apply (wp shrink_zombie_invs')[1]
          apply (wp | simp)+
         apply (rule getCTE_wp)
        apply (wp | simp)+
      apply (rule_tac Q="\<lambda>cte s. rv = capZombiePtr cap +
                                      of_nat (capZombieNumber cap) * 16 - 16
                              \<and> cte_wp_at' (\<lambda>c. c = cte) slot s \<and> invs' s
                              \<and> vs_valid_duplicates' (ksPSpace s) \<and> sch_act_simple s"
                  in hoare_post_imp)
       apply (clarsimp simp: cte_wp_at_ctes_of mult.commute mult.left_commute dest!: isCapDs)
       apply (simp add: field_simps)
      apply (wp getCTE_cte_wp_at)
      apply simp
      apply wp[1]
     apply (rule spec_strengthen_postE)
      apply (rule_tac Q="\<lambda>fc s. rv = capZombiePtr cap +
                                      of_nat (capZombieNumber cap) * 16 - 16"
                 in spec_valid_conj_liftE1)
       apply wp[1]
      apply (rule fin, assumption+)
     apply clarsimp
    apply (simp add: locateSlot_conv)
    apply ((wp | simp)+)[2]
  apply (clarsimp simp: cte_wp_at_ctes_of)
  apply (rule conjI)
   apply (clarsimp dest!: isCapDs)
   apply (rule conjI)
    apply (erule(1) ex_Zombie_to)
     apply clarsimp
    apply clarsimp
   apply clarsimp
  apply (clarsimp simp: cte_level_bits_def dest!: isCapDs)
  apply (erule(1) ex_Zombie_to2)
   apply clarsimp+
  done

lemma finaliseSlot_valid_duplicates_spec':
  "st \<turnstile> \<lbrace>\<lambda>s.
      invs' s \<and> vs_valid_duplicates' (ksPSpace s) \<and> sch_act_simple s
              \<and> (exposed \<or> ex_cte_cap_to' slot s)
              \<and> (exposed \<or> p = slot \<or>
                  cte_wp_at' (\<lambda>cte. (P and isZombie) (cteCap cte)
                                  \<or> (\<exists>zb n cp. cteCap cte = Zombie p zb n
                                       \<and> P cp \<and> (isZombie cp \<longrightarrow> capZombiePtr cp \<noteq> p))) p s)\<rbrace>
       finaliseSlot' slot exposed
   \<lbrace>\<lambda>rv s.
      invs' s \<and> vs_valid_duplicates' (ksPSpace s) \<and> sch_act_simple s
              \<and> (exposed \<or> p = slot \<or>
                  cte_wp_at' (\<lambda>cte. (P and isZombie) (cteCap cte)
                                  \<or> (\<exists>zb n cp. cteCap cte = Zombie p zb n
                                       \<and> P cp \<and> (isZombie cp \<longrightarrow> capZombiePtr cp \<noteq> p))) p s)
              \<and> (fst rv \<longrightarrow> cte_wp_at' (\<lambda>cte. removeable' slot s (cteCap cte)) slot s)
              \<and> (\<forall>irq sl'. snd rv = Some irq \<longrightarrow> sl' \<noteq> slot \<longrightarrow> cteCaps_of s sl' \<noteq> Some (IRQHandlerCap irq))\<rbrace>,
   \<lbrace>\<lambda>rv s. invs' s \<and> vs_valid_duplicates' (ksPSpace s) \<and> sch_act_simple s\<rbrace>"
proof (induct arbitrary: P p rule: finalise_spec_induct2)
  case (1 sl exp s Q q)
  let ?P = "\<lambda>cte. (Q and isZombie) (cteCap cte)
                     \<or> (\<exists>zb n cp. cteCap cte = Zombie q zb n
                          \<and> Q cp \<and> (isZombie cp \<longrightarrow> capZombiePtr cp \<noteq> q))"
  note hyps = "1.hyps"[folded reduceZombie_def[unfolded cteDelete_def finaliseSlot_def]]
  have Q: "\<And>x y n. {x :: word32} = (\<lambda>x. y + x * 0x10) ` {0 ..< n} \<Longrightarrow> n = 1"
    apply (drule sym)
    apply (case_tac "1 < n")
     apply (frule_tac x = "y + 0 * 0x10" in eqset_imp_iff)
     apply (frule_tac x = "y + 1 * 0x10" in eqset_imp_iff)
     apply (subst(asm) imageI, simp)
      apply (erule order_less_trans[rotated], simp)
     apply (subst(asm) imageI, simp)
     apply simp
    apply (simp add: linorder_not_less)
    apply (case_tac "n < 1")
     apply simp
    apply simp
    done
  have R: "\<And>n. n \<noteq> 0 \<Longrightarrow> {0 .. n - 1} = {0 ..< n :: word32}"
    apply safe
     apply simp
     apply (erule(1) minus_one_helper5)
    apply simp
    apply (erule minus_one_helper3)
    done
  have final_IRQHandler_no_copy:
    "\<And>irq sl sl' s. \<lbrakk> isFinal (IRQHandlerCap irq) sl (cteCaps_of s); sl \<noteq> sl' \<rbrakk> \<Longrightarrow> cteCaps_of s sl' \<noteq> Some (IRQHandlerCap irq)"
    apply (clarsimp simp: isFinal_def sameObjectAs_def2 isCap_simps)
    apply fastforce
    done
  show ?case
    apply (subst finaliseSlot'.simps)
    apply (fold reduceZombie_def[unfolded cteDelete_def finaliseSlot_def])
    apply (unfold split_def)
    apply (rule hoare_pre_spec_validE)
     apply (wp | simp)+
         apply (wp make_zombie_invs' updateCap_cte_wp_at_cases
                   hoare_vcg_disj_lift)[1]
        apply (wp hyps, assumption+)  
          apply ((wp preemptionPoint_invE preemptionPoint_invR|simp)+)[1]
         apply (rule spec_strengthen_postE [OF reduceZombie_valid_duplicates_spec'])
          prefer 2
          apply fastforce
         apply (rule hoare_pre_spec_validE,
                rule spec_strengthen_postE)
          apply (unfold finaliseSlot_def)[1]
           apply (rule hyps[where P="\<top>" and p=sl], (assumption | rule refl)+)
          apply clarsimp
         apply (clarsimp simp: cte_wp_at_ctes_of)
        apply (wp, simp)
        apply (wp make_zombie_invs' updateCap_ctes_of_wp updateCap_cap_to'
                  hoare_vcg_disj_lift updateCap_cte_wp_at_cases)
       apply simp
       apply (rule hoare_strengthen_post)
        apply (rule_tac Q="\<lambda>fin s. invs' s \<and> vs_valid_duplicates' (ksPSpace s)
                                 \<and> sch_act_simple s
                                 \<and> s \<turnstile>' (fst fin)
                                 \<and> (exp \<or> ex_cte_cap_to' sl s)
                                 \<and> cte_wp_at' (\<lambda>cte. cteCap cte = cteCap rv) sl s
                                 \<and> (q = sl \<or> exp \<or> cte_wp_at' (?P) q s)"
                   in hoare_vcg_conj_lift)
         apply (wp hoare_vcg_disj_lift finaliseCap_invs[where sl=sl])
         apply (rule finaliseCap_zombie_cap')
        apply (rule hoare_vcg_conj_lift)
         apply (rule finaliseCap_cte_refs)
        apply (rule finaliseCap_replaceable[where slot=sl])
       apply clarsimp
       apply (erule disjE[where P="F \<and> G" for F G])
        apply (clarsimp simp: capRemovable_def cte_wp_at_ctes_of)
        apply (rule conjI, clarsimp)
        apply (clarsimp simp: final_IRQHandler_no_copy)
       apply (clarsimp dest!: isCapDs)
       apply (rule conjI)
        apply (clarsimp simp: capRemovable_def)
        apply (rule conjI)
         apply (clarsimp simp: cte_wp_at_ctes_of)
         apply (rule conjI, clarsimp)
         apply (case_tac "cteCap rv",
                simp_all add: isCap_simps removeable'_def
                              fun_eq_iff[where f="cte_refs' cap" for cap]
                              fun_eq_iff[where f=tcb_cte_cases]
                              tcb_cte_cases_def
                              word_neq_0_conv[symmetric])[1]
        apply (clarsimp simp: cte_wp_at_ctes_of)
        apply (rule conjI, clarsimp)
        apply (case_tac "cteCap rv",
               simp_all add: isCap_simps removeable'_def
                             fun_eq_iff[where f="cte_refs' cap" for cap]
                             fun_eq_iff[where f=tcb_cte_cases]
                             tcb_cte_cases_def)[1]
         apply (frule Q)
         apply clarsimp
        apply (subst(asm) R)
         apply (drule valid_capAligned [OF ctes_of_valid'])
          apply fastforce
         apply (simp add: capAligned_def word_bits_def objBits_simps)
        apply (frule Q)
        apply clarsimp
       apply (clarsimp simp: cte_wp_at_ctes_of capRemovable_def)
       apply (subgoal_tac "final_matters' (cteCap rv) \<and> \<not> isUntypedCap (cteCap rv)")
        apply clarsimp
        apply (rule conjI)
         apply clarsimp
        apply clarsimp
       apply (case_tac "cteCap rv",
              simp_all add: isCap_simps final_matters'_def)[1]
      apply (wp isFinalCapability_inv static_imp_wp | simp | wp_once isFinal[where x=sl])+
     apply (wp getCTE_wp')
    apply (clarsimp simp: cte_wp_at_ctes_of disj_ac)
    apply (rule conjI, clarsimp simp: removeable'_def)
    apply (clarsimp simp: conj_ac invs_pspace_aligned' invs_valid_objs')
    apply (rule conjI, erule ctes_of_valid', clarsimp)
    apply (rule conjI, clarsimp)
    apply (fastforce)
    done
qed

lemma finaliseSlot_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. invs' s \<and> vs_valid_duplicates' (ksPSpace s) \<and> sch_act_simple s 
    \<and> (\<not> exposed \<longrightarrow> ex_cte_cap_to' slot s) \<rbrace>
  finaliseSlot slot exposed
  \<lbrace>\<lambda>_ s. invs' s \<and> vs_valid_duplicates' (ksPSpace s) \<and> sch_act_simple s \<rbrace>"
  apply (unfold finaliseSlot_def)
  apply wp
  apply (rule hoare_pre,rule use_spec)
   apply (rule spec_strengthen_postE)
    apply (rule finaliseSlot_valid_duplicates_spec'[where p=slot])
   apply clarsimp
  apply clarsimp
  done

lemma cteDelete_valid_duplicates':
  "\<lbrace>invs' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and sch_act_simple and K ex\<rbrace>
  cteDelete ptr ex 
  \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (simp add: cteDelete_def whenE_def split_def)
  apply (rule hoare_pre, wp finaliseSlot_invs)
   apply simp
   apply (rule valid_validE)
   apply (rule hoare_post_imp[OF _ finaliseSlot_valid_duplicates'])
   apply simp
  apply simp
  done

lemma cteRevoke_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. invs' s
        \<and> vs_valid_duplicates' (ksPSpace s)
        \<and> sch_act_simple s \<rbrace>
    cteRevoke cte
  \<lbrace>\<lambda>_ s. invs' s
       \<and> vs_valid_duplicates' (ksPSpace s)
       \<and> sch_act_simple s \<rbrace>"
  apply (rule cteRevoke_preservation)
   apply (wp cteDelete_invs' cteDelete_valid_duplicates' cteDelete_sch_act_simple)
     apply (simp add:cteDelete_def)+
  done

lemma mapM_x_storePTE_invalid_whole:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s) \<and>
  s \<turnstile>' capability.ArchObjectCap (arch_capability.PageTableCap word option) \<and>
  pspace_aligned' s\<rbrace>
  mapM_x (swp storePTE Hardware_H.pte.InvalidPTE)
  [word , word + 2 ^ objBits Hardware_H.pte.InvalidPTE .e. word + 2 ^ ptBits - 1] 
  \<lbrace>\<lambda>y s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (wp mapM_x_storePTE_update_helper
    [where word = word and sz = ptBits and ptr = word])
  apply (clarsimp simp:valid_cap'_def capAligned_def pageBits_def
    ptBits_def is_aligned_neg_mask_eq objBits_simps
    archObjSize_def)
  apply (simp add:mask_def field_simps)
  done

lemma mapM_x_storePDE_update_invalid:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s) \<and>
       (\<exists>option. s \<turnstile>' capability.ArchObjectCap (arch_capability.PageDirectoryCap word option)) \<and>
  pspace_aligned' s\<rbrace>
  mapM_x (swp storePDE Hardware_H.pde.InvalidPDE)
  (map ((\<lambda>x. x + word) \<circ>
                 swp op << (objBits Hardware_H.pde.InvalidPDE))
             [0.e.(kernelBase >> 20) - 1])
  \<lbrace>\<lambda>y s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
proof -
  have word_le_significant_bits:
  "\<And>x p. x \<le> (0xEFF::word32)
  \<Longrightarrow> (p && mask 6) + ((x << 2) && ~~ mask 6) >> 2 \<le> 0xEFF"
   apply (simp add:mask_def)
   apply (word_bitwise)
   apply simp
   done
  show ?thesis
  apply (wp mapM_x_storePDE_updates)
  apply (intro conjI)
   apply (clarsimp simp:valid_cap'_def page_directory_at'_def
     capAligned_def archObjSize_def objBits_simps )
   apply (clarsimp simp:archObjSize_def pageBits_def pdBits_def)
   apply (drule_tac x = x in spec)
    apply (clarsimp dest!:plus_one_helper
      simp:kernelBase_def le_less_trans field_simps)
  apply (clarsimp simp:valid_cap'_def 
    objBits_simps archObjSize_def)
  apply (subst vs_valid_duplicates'_def)
  apply (thin_tac "case_option ?x ?y ?z")
  apply (clarsimp simp: dom_def vs_ptr_align_def capAligned_def)
  apply (intro conjI impI)
   apply (clarsimp simp:image_def split:option.splits)
   apply (subgoal_tac "x && ~~ mask 6 \<noteq> ((xa << 2) + word) && ~~ mask 6")
    apply (drule irrelevant_ptr)
     apply (simp add:pdBits_def pageBits_def)
    apply fastforce
   apply (simp add:field_simps)
   apply (rule ccontr)
   apply simp
   apply (simp add:mask_out_add_aligned[where n =6,
     OF is_aligned_weaken[where x = 14],simplified,symmetric])
   apply (subst (asm) mask_out_sub_mask)
   apply (simp add:field_simps)
   apply (drule_tac x = "((x && mask 6) + ((xa << 2) && ~~ mask 6)) >> 2" in spec)
    apply (clarsimp simp: kernelBase_def word_le_significant_bits)
   apply (subst (asm) shiftr_shiftl1)
    apply simp
   apply (simp add:mask_lower_twice)
   apply (subst (asm) is_aligned_neg_mask_eq[where n = 2])
    apply (rule aligned_add_aligned[where n = 2])
      apply (rule is_aligned_andI1)
      apply (drule(1) pspace_alignedD')
      apply (case_tac x2,simp_all add:objBits_simps
        pageBits_def archObjSize_def
        is_aligned_weaken[where y = 2]
        split:arch_kernel_object.splits)
    apply (simp add:is_aligned_neg_mask)
   apply (simp add:mask_out_sub_mask field_simps)
  apply (clarsimp split:option.splits)
  apply (drule_tac p' = y in valid_duplicates'_D)
    apply simp+
  done
qed

crunch valid_objs'[wp]:
  invalidateTLBByASID valid_objs'
  (wp: crunch_wps simp: crunch_simps unless_def ignore:getObject setObject)

crunch pspace_aligned'[wp]:
  invalidateTLBByASID pspace_aligned'
  (wp: crunch_wps simp: crunch_simps unless_def ignore:getObject setObject)

thm vs_valid_duplicates'_def

lemma recycleCap_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. valid_objs' s \<and> pspace_aligned' s \<and> vs_valid_duplicates' (ksPSpace s) 
    \<and> valid_cap' cte s \<and> pspace_aligned' s\<rbrace>
   recycleCap is_final cte
  \<lbrace>\<lambda>_ s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (case_tac cte)
  apply (simp_all add: isCap_simps recycleCap_def)
           apply (wp|simp|wpc)+
       apply (rule hoare_pre)
        apply (wp hoare_drop_imp|simp|wpc)+
      apply (case_tac arch_capability)
          apply (simp add:ArchRetype_H.recycleCap_def Let_def
            isCap_simps split del:if_splits | wp hoare_drop_imps hoare_vcg_all_lift |wpc)+
         apply (rule_tac Q = "\<lambda>r s. valid_objs' s \<and>
           pspace_aligned' s \<and>
           vs_valid_duplicates' (ksPSpace s) \<and>
           s \<turnstile>' capability.ArchObjectCap (arch_capability.PageTableCap word option)"
           in hoare_post_imp)
         apply (clarsimp simp:conj_ac)
         apply (rule hoare_vcg_conj_lift[OF mapM_x_wp'])
          apply (simp add:valid_pte'_def|wp)+
         apply (rule hoare_vcg_conj_lift[OF mapM_x_wp'])
          apply (simp add:valid_pte'_def|wp)+
         apply (wp mapM_x_storePTE_invalid_whole)
          apply (wp mapM_x_wp'|simp)+
         apply fastforce
        apply (simp add:ArchRetype_H.recycleCap_def Let_def
          isCap_simps split del:if_splits | wp hoare_drop_imps hoare_vcg_all_lift
          |wpc)+
        apply (clarsimp simp:conj_ac)
        apply (rule_tac Q = "\<lambda>r s. valid_objs' s \<and>
          pspace_aligned' s \<and>
          vs_valid_duplicates' (ksPSpace s) \<and>
          s \<turnstile>' capability.ArchObjectCap (arch_capability.PageDirectoryCap word option)"
           in hoare_post_imp)
         apply (clarsimp simp:conj_ac)
        apply (rule hoare_pre)
         apply (rule hoare_vcg_conj_lift[OF mapM_x_wp'])
          apply (simp add:valid_pte'_def|wp)+
         apply (rule hoare_vcg_conj_lift[OF mapM_x_wp'])
          apply (simp add:valid_pte'_def|wp)+
         apply (wp mapM_x_storePDE_update_invalid)
         apply (wp mapM_x_wp' | simp)+
        apply fastforce
     apply (simp|wp)+
  done

crunch valid_duplicates'[wp]:
  isFinalCapability "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
  (wp: crunch_wps filterM_preserved simp: crunch_simps unless_def 
    ignore:getObject setObject)

crunch valid_cap'[wp]:
  isFinalCapability "\<lambda>s. valid_cap' cap s"
  (wp: crunch_wps filterM_preserved simp: crunch_simps unless_def 
    ignore:getObject setObject)

lemma invokeIRQControl_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s) \<rbrace> invokeIRQControl a
  \<lbrace>\<lambda>_ s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:invokeIRQControl_def invokeInterruptControl_def)
  apply (rule hoare_pre)
  apply (wp|wpc | simp add:invokeInterruptControl_def)+
  apply fastforce
 done

lemma invokeIRQHandler_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s) \<rbrace> invokeIRQHandler a
  \<lbrace>\<lambda>_ s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:invokeIRQHandler_def)
  apply (rule hoare_pre)
  apply (wp|wpc | simp add:invokeInterruptControl_def)+
  done

lemma invokeCNode_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. invs' s \<and> sch_act_simple s \<and> vs_valid_duplicates' (ksPSpace s)
  \<and> valid_cnode_inv' cinv s\<rbrace> invokeCNode cinv
  \<lbrace>\<lambda>_ s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (case_tac cinv)
        apply (clarsimp simp add:invokeCNode_def | wp | intro conjI)+
      apply (rule hoare_pre)
       apply (rule valid_validE)
       apply (rule hoare_post_imp[OF _ cteRevoke_valid_duplicates'])
       apply simp
      apply (simp add:invs_valid_objs' invs_pspace_aligned')
     apply (clarsimp simp add:invokeCNode_def | wp | intro conjI)+
    apply (rule hoare_pre)
    apply (simp add:cteRecycle_def)
    apply (wp hoare_unless_wp isFinalCapability_inv)
      apply (rule hoare_post_imp
        [where Q ="\<lambda>r s. valid_cap' (cteCap r) s 
          \<and> vs_valid_duplicates' (ksPSpace s) \<and> valid_objs' s 
          \<and> pspace_aligned' s"])
       apply simp
      apply (wp getCTE_valid_cap)
      apply (clarsimp simp:conj_ac)
      apply (rule hoare_post_impErr[OF valid_validE])
        apply (rule finaliseSlot_valid_duplicates')
       apply (simp add:invs_pspace_aligned' invs_valid_objs')
      apply simp
     apply (rule hoare_post_impErr[OF valid_validE])
       apply (rule cteRevoke_valid_duplicates')
      apply simp
     apply simp
    apply (simp add:invs_valid_objs' invs_pspace_aligned')
   apply (simp add:invokeCNode_def)
   apply (wp getSlotCap_inv hoare_drop_imp
     |simp add:locateSlot_def getThreadCallerSlot_def
     |wpc)+
  apply (simp add:cteDelete_def invokeCNode_def)
  apply (wp getSlotCap_inv hoare_drop_imp
     |simp add:locateSlot_def getThreadCallerSlot_def
    whenE_def split_def
     |wpc)+
  apply (rule hoare_pre)
  apply (rule valid_validE)
   apply (rule hoare_post_imp[OF _ finaliseSlot_valid_duplicates'])
   apply simp
  apply (simp add:invs_valid_objs' invs_pspace_aligned')
  done

lemma getObject_pte_sp:
  "\<lbrace>P\<rbrace> getObject r \<lbrace>\<lambda>t::pte. P and ko_at' t r\<rbrace>"
  apply (wp getObject_ko_at)
  apply (auto simp: objBits_simps archObjSize_def)
  done

lemma getObject_pde_sp:
  "\<lbrace>P\<rbrace> getObject r \<lbrace>\<lambda>t::pde. P and ko_at' t r\<rbrace>"
  apply (wp getObject_ko_at)
  apply (auto simp: objBits_simps archObjSize_def)
  done

lemma performPageInvocation_valid_duplicates'[wp]:
  "\<lbrace>invs' and valid_arch_inv' (invocation.InvokePage page_invocation) 
  and (\<lambda>s. vs_valid_duplicates' (ksPSpace s))\<rbrace>
    performPageInvocation page_invocation 
    \<lbrace>\<lambda>y a. vs_valid_duplicates' (ksPSpace a)\<rbrace>"
  apply (rule hoare_name_pre_state)
  apply (case_tac page_invocation)
  -- "PageFlush"
     apply (simp_all add:performPageInvocation_def pteCheckIfMapped_def pdeCheckIfMapped_def)
     apply (wp|simp|wpc)+
     -- "PageRemap"
    apply (case_tac sum)
     apply (case_tac a)
     apply (case_tac aa)
       apply (clarsimp simp:valid_arch_inv'_def
          valid_page_inv'_def valid_slots'_def
          valid_slots_duplicated'_def mapM_singleton)
       apply (wp PageTableDuplicates.storePTE_no_duplicates' getPTE_wp | simp add: if_cancel)+
       apply (simp add:vs_entry_align_def)
      apply (subst mapM_discarded)
      apply simp
      apply (rule hoare_seq_ext[OF _ getObject_pte_sp])
      apply (wp|simp)+
      apply (clarsimp simp:valid_arch_inv'_def
        valid_page_inv'_def valid_slots'_def
        valid_slots_duplicated'_def)
      apply (rule hoare_pre)
       apply (rule_tac sz = 6 and ptr = "p && ~~ mask ptBits" and word = p 
         in mapM_x_storePTE_update_helper)
      apply (simp add:invs_pspace_aligned' pageBits_def ptBits_def)
     apply (subst mapM_discarded)
     apply (clarsimp simp:valid_arch_inv'_def
          valid_page_inv'_def valid_slots'_def
          valid_slots_duplicated'_def mapM_x_singleton)
     apply (rule hoare_seq_ext[OF _ getObject_pte_sp])
     apply (wp PageTableDuplicates.storePTE_no_duplicates' | simp)+
     apply (simp add:vs_entry_align_def)
    apply (subst mapM_discarded)+
    apply (case_tac b)
    apply (case_tac a)
       apply (clarsimp simp:valid_arch_inv'_def
          valid_page_inv'_def valid_slots'_def
          valid_slots_duplicated'_def mapM_x_singleton)
       apply (rule hoare_seq_ext[OF _ getObject_pde_sp])
       apply (wp PageTableDuplicates.storePDE_no_duplicates' | simp add: when_def)+
       apply (simp add: vs_entry_align_def)+
      apply (rule hoare_seq_ext[OF _ getObject_pde_sp])
      apply (wp|wpc|simp add:vs_entry_align_def)+
      apply (clarsimp simp:valid_arch_inv'_def vs_entry_align_def
          valid_page_inv'_def valid_slots'_def
          valid_slots_duplicated'_def mapM_x_singleton)
      apply ((wp PageTableDuplicates.storePDE_no_duplicates' | wpc | simp)+)[1]
      apply (simp add: vs_entry_align_def)+
     apply (rule hoare_seq_ext[OF _ getObject_pde_sp])
     apply (wp|wpc|simp add:vs_entry_align_def)+
     apply (clarsimp simp:valid_arch_inv'_def
          valid_page_inv'_def valid_slots'_def
          valid_slots_duplicated'_def mapM_x_singleton)
     apply (wp PageTableDuplicates.storePDE_no_duplicates')
     apply (simp add: vs_entry_align_def)+
    apply (rule hoare_seq_ext[OF _ getObject_pde_sp])
    apply (wp|wpc|simp add:vs_entry_align_def)+
    apply (clarsimp simp:valid_arch_inv'_def
          valid_page_inv'_def valid_slots'_def
          valid_slots_duplicated'_def mapM_x_singleton)
    apply (rule hoare_pre)
     apply (rule_tac sz = 6 and ptr = "p && ~~ mask pdBits" and word = p
         in mapM_x_storePDE_update_helper)
    apply clarsimp
    apply (simp add:invs_pspace_aligned' ptBits_def
      pdBits_def field_simps pageBits_def)+
   -- "PageMap"
   apply (clarsimp simp: pteCheckIfMapped_def pdeCheckIfMapped_def)
   apply (clarsimp simp:valid_pde_slots'_def valid_page_inv'_def
       valid_slots_duplicated'_def valid_arch_inv'_def )
   apply (case_tac sum)
    apply (case_tac a)
    apply (case_tac aa)
      apply (clarsimp simp: pteCheckIfMapped_def)
      apply (wp mapM_x_mapM_valid |wpc
        | simp)+
        apply (clarsimp simp:valid_slots_duplicated'_def mapM_x_singleton)+
        apply (rule PageTableDuplicates.storePTE_no_duplicates', rule getPTE_wp)
      apply (wp hoare_vcg_all_lift hoare_drop_imps)
      apply (simp add:vs_entry_align_def)+
     apply (clarsimp simp: pteCheckIfMapped_def)
     apply (wp mapM_x_mapM_valid | simp)+
       apply (rule_tac sz = 6 and ptr = "p && ~~ mask ptBits" and word = p in
         mapM_x_storePTE_update_helper)
      apply (wp getPTE_wp hoare_vcg_all_lift hoare_drop_imps)
     apply (simp add:ptBits_def pageBits_def)+
     apply (simp add:invs_pspace_aligned')
    apply simp
    apply (clarsimp simp:mapM_singleton pteCheckIfMapped_def)
    apply (wp PageTableDuplicates.storePTE_no_duplicates' getPTE_wp hoare_drop_imps | simp)+
      apply (simp add:vs_entry_align_def)+
   apply (clarsimp simp: pdeCheckIfMapped_def)
   apply (case_tac a)
      apply (clarsimp simp:valid_arch_inv'_def
          valid_page_inv'_def valid_slots'_def
          valid_slots_duplicated'_def mapM_singleton)
      apply (wp PageTableDuplicates.storePDE_no_duplicates' getPDE_wp hoare_drop_imps | simp)+
        apply (simp add:vs_entry_align_def)+
     apply (clarsimp simp:valid_arch_inv'_def
          valid_page_inv'_def valid_slots'_def
          valid_slots_duplicated'_def mapM_singleton)
     apply (wp PageTableDuplicates.storePDE_no_duplicates' getPDE_wp hoare_drop_imps | simp)+
       apply (simp add:vs_entry_align_def)+
    apply (clarsimp simp:valid_arch_inv'_def
          valid_page_inv'_def valid_slots'_def
          valid_slots_duplicated'_def mapM_singleton)
    apply (wp PageTableDuplicates.storePDE_no_duplicates' getPDE_wp hoare_drop_imps | simp)+
      apply (simp add:vs_entry_align_def)+
   apply (clarsimp simp:valid_arch_inv'_def
          valid_page_inv'_def valid_slots'_def
          valid_slots_duplicated'_def mapM_x_singleton)
   apply (wp mapM_x_mapM_valid | simp)+
     apply (rule_tac sz = 6 and ptr = "p && ~~ mask pdBits" and word = p
          in mapM_x_storePDE_update_helper)
    apply wp
      apply (simp add:pageBits_def pdBits_def ptBits_def)+
    apply (simp add:invs_pspace_aligned')+
  apply clarsimp
  apply (rule hoare_pre)
   apply (wp |wpc |simp)+
  apply (clarsimp simp:valid_page_inv'_def
      valid_arch_inv'_def valid_cap'_def invs_valid_objs' invs_pspace_aligned')
  done

lemma placeASIDPool_valid_duplicates'[wp]:
  notes blah[simp del] = atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
          Int_atLeastAtMost atLeastatMost_empty_iff split_paired_Ex
  shows "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s) \<and> pspace_no_overlap' ptr pageBits s 
   \<and> is_aligned ptr pageBits \<and> pspace_aligned' s\<rbrace>
  placeNewObject' ptr (KOArch (KOASIDPool makeObject)) 0 
  \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:placeNewObject'_def)
  apply (wp hoare_unless_wp | wpc | 
    simp add:alignError_def split_def)+
  apply (subgoal_tac "vs_valid_duplicates' (\<lambda>a. if a = ptr then Some (KOArch (KOASIDPool makeObject)) else ksPSpace s a)")
   apply fastforce
  apply (subst vs_valid_duplicates'_def)
  apply (clarsimp simp: vs_entry_align_def
         foldr_upd_app_if[unfolded data_map_insert_def[symmetric]])
  apply (clarsimp split:option.splits 
         simp:foldr_upd_app_if[unfolded data_map_insert_def[symmetric]]
         vs_entry_align_def vs_ptr_align_def)
  apply (rule conjI)
   apply clarsimp
   apply (subgoal_tac "x \<in> obj_range' x x2")
    apply (subgoal_tac "x\<in> {ptr .. ptr + 2 ^ 12 - 1}")
     apply (drule(2) pspace_no_overlapD3')
      apply (simp add:pageBits_def)
      apply blast
    apply (simp add: pageBits_def
     split : Hardware_H.pte.splits Hardware_H.pde.splits 
     arch_kernel_object.splits Structures_H.kernel_object.splits )
     apply (drule mask_out_first_mask_some[where m = 12])
      apply simp
     apply (clarsimp simp:mask_lower_twice field_simps
       is_aligned_neg_mask_eq blah word_and_le2)
     apply (rule order_trans[OF and_neg_mask_plus_mask_mono[where n = 12]])
     apply (simp add:mask_def)
    apply (drule mask_out_first_mask_some[where m = 12])
     apply simp
    apply (clarsimp simp:mask_lower_twice field_simps
      is_aligned_neg_mask_eq blah word_and_le2)
    apply (rule order_trans[OF and_neg_mask_plus_mask_mono[where n = 12]])
    apply (simp add:mask_def)
   apply (simp add:obj_range'_def blah)
   apply (rule is_aligned_no_overflow)
   apply (drule(2) pspace_alignedD')
  apply clarsimp
  apply (drule valid_duplicates'_D)
     apply (simp add:vs_entry_align_def vs_ptr_align_def)+
  done

lemma setASIDPool_valid_duplicates':
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
  setObject poolPtr $ (ap::asidpool)
  \<lbrace>\<lambda>r s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:setObject_def)
  apply (clarsimp simp: setObject_def split_def valid_def in_monad
                        projectKOs pspace_aligned'_def ps_clear_upd'
                        objBits_def[symmetric] lookupAround2_char1
                 split: split_if_asm)
  apply (frule pspace_storable_class.updateObject_type[where v = ap,simplified])
  apply (clarsimp simp:updateObject_default_def assert_def bind_def 
    alignCheck_def in_monad when_def alignError_def magnitudeCheck_def
    assert_opt_def return_def fail_def typeError_def
    split:if_splits option.splits Structures_H.kernel_object.splits)
     apply (erule valid_duplicates'_non_pd_pt_I[rotated 3],clarsimp+)+
  done

lemma performArchInvocation_valid_duplicates':
  "\<lbrace>invs' and valid_arch_inv' ai and ct_active' and st_tcb_at' active' p
    and (\<lambda>s. vs_valid_duplicates' (ksPSpace s))\<rbrace>
     ArchRetypeDecls_H.performInvocation ai
   \<lbrace>\<lambda>reply s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add: ArchRetype_H.performInvocation_def performARMMMUInvocation_def)
  apply (cases ai, simp_all)
      apply (case_tac page_table_invocation)
       apply (rule hoare_name_pre_state)
       apply (clarsimp simp:valid_arch_inv'_def valid_pti'_def isCap_simps
              cte_wp_at_ctes_of is_arch_update'_def isPageTableCap_def
              split:arch_capability.splits)
       apply (clarsimp simp: performPageTableInvocation_def)
       apply (rule hoare_pre)
        apply (simp | wp getSlotCap_inv mapM_x_storePTE_invalid_whole[unfolded swp_def]
           | wpc)+
       apply fastforce
      apply (rule hoare_name_pre_state)
      apply (clarsimp simp:valid_arch_inv'_def isCap_simps valid_pti'_def
        cte_wp_at_ctes_of is_arch_update'_def isPageTableCap_def
        split:arch_capability.splits)
      apply (clarsimp simp: performPageTableInvocation_def)
      apply (wp storePDE_no_duplicates' | simp)+
     apply (case_tac page_directory_invocation,
            simp_all add:performPageDirectoryInvocation_def)[]
      apply (wp, simp)
     apply (wp)
       apply (simp, rule doMachineOp_valid_duplicates')
      apply (wp)
     apply (simp)
    apply(wp, simp)
   apply (case_tac asidcontrol_invocation)
   apply (simp add:performASIDControlInvocation_def )
   apply (clarsimp simp:valid_aci'_def valid_arch_inv'_def)
   apply (rule hoare_name_pre_state)
   apply (clarsimp simp:cte_wp_at_ctes_of)
   apply (case_tac ctea,clarsimp)
   apply (frule(1) ctes_of_valid_cap'[OF _ invs_valid_objs'])
   apply (wp static_imp_wp|simp)+
      apply (simp add:placeNewObject_def)
      apply (wp |simp add:alignError_def unless_def|wpc)+
     apply (wp updateFreeIndex_pspace_no_overlap' hoare_drop_imp
       getSlotCap_cte_wp_at deleteObject_no_overlap
       deleteObjects_invs_derivatives deleteObject_no_overlap)
        apply (clarsimp simp:cte_wp_at_ctes_of)
        apply (intro conjI)
          apply fastforce
         apply (simp add:descendants_range'_def2 empty_descendants_range_in')
        apply (fastforce simp:valid_cap'_def capAligned_def)+
     apply (clarsimp simp:cte_wp_at_ctes_of)
     apply (intro conjI)
       apply fastforce
      apply (simp add:descendants_range'_def2 empty_descendants_range_in')
     apply (fastforce simp:valid_cap'_def capAligned_def)+
  apply (case_tac asidpool_invocation)
  apply (clarsimp simp:performASIDPoolInvocation_def)
  apply (wp | simp)+
  done

crunch valid_duplicates' [wp]: restart "(\<lambda>s. vs_valid_duplicates' (ksPSpace s))"
  (wp: crunch_wps)

crunch valid_duplicates' [wp]: setPriority "(\<lambda>s. vs_valid_duplicates' (ksPSpace s))"
  (ignore: getObject threadSet wp: setObject_ksInterrupt updateObject_default_inv
    simp:crunch_simps)

crunch inv [wp]: getThreadBufferSlot P
  (wp: crunch_wps)

lemma tc_valid_duplicates':
  "\<lbrace>invs' and sch_act_simple and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and tcb_at' a and ex_nonz_cap_to' a and
    case_option \<top> (valid_cap' o fst) e' and 
    K (case_option True (isCNodeCap o fst) e') and
    case_option \<top> (valid_cap' o fst) f' and
    K (case_option True (isValidVTableRoot o fst) f') and
    case_option \<top> (valid_cap') (case_option None (case_option None (Some o fst) o snd) g) and
    K (case_option True (\<lambda>x. x \<le> maxPriority) d) and 
    K (case_option True isArchObjectCap (case_option None (case_option None (Some o fst) o snd) g))
    and K (case_option True (swp is_aligned msg_align_bits o fst) g)\<rbrace>
      invokeTCB (tcbinvocation.ThreadControl a sl b' d e' f' g)
   \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (simp add: split_def invokeTCB_def getThreadCSpaceRoot getThreadVSpaceRoot
                   getThreadBufferSlot_def locateSlot_conv
             cong: option.case_cong)
  apply (rule hoare_walk_assmsE)
    apply (clarsimp simp: pred_conj_def option.splits [where P="\<lambda>x. x s" for s])
    apply ((wp case_option_wp threadSet_invs_trivial
               hoare_vcg_all_lift threadSet_cap_to' static_imp_wp | simp add: inQ_def | fastforce)+)[2]
  apply (rule hoare_walk_assmsE)
    apply (clarsimp simp: pred_conj_def option.splits [where P="\<lambda>x. x s" for s])
    apply ((wp case_option_wp threadSet_invs_trivial setP_invs' static_imp_wp
               hoare_vcg_all_lift threadSet_cap_to' | simp add: inQ_def | fastforce)+)[2]
  apply (rule hoare_pre)
   apply ((simp only: simp_thms cases_simp cong: conj_cong
         | (wp cteDelete_deletes cteDelete_invs' cteDelete_sch_act_simple
               threadSet_ipcbuffer_trivial
               checkCap_inv[where P="tcb_at' t" for t]
               checkCap_inv[where P="valid_cap' c" for c]
               checkCap_inv[where P="\<lambda>s. P (ksReadyQueues s)" for P]
               checkCap_inv[where P="\<lambda>s. vs_valid_duplicates' (ksPSpace s)"]
               checkCap_inv[where P=sch_act_simple]
               cteDelete_valid_duplicates'
               hoare_vcg_const_imp_lift_R
               typ_at_lifts [OF setPriority_typ_at'] 
               assertDerived_wp
               threadSet_cte_wp_at'
               hoare_vcg_all_lift_R
               hoare_vcg_all_lift
               static_imp_wp
               )[1]
         | wpc
         | simp add: inQ_def
         | wp hoare_vcg_conj_liftE1 cteDelete_invs' cteDelete_deletes
              hoare_vcg_const_imp_lift
         )+)
  apply (clarsimp simp: tcb_cte_cases_def cte_level_bits_def
                        tcbIPCBufferSlot_def)
  apply (auto dest!: isCapDs isReplyCapD isValidVTableRootD
               simp: isCap_simps)
  done

crunch valid_duplicates' [wp]: performTransfer "(\<lambda>s. vs_valid_duplicates' (ksPSpace s))"
  (ignore: getObject threadSet wp: setObject_ksInterrupt updateObject_default_inv
    simp:crunch_simps)

crunch valid_duplicates' [wp]: setDomain "(\<lambda>s. vs_valid_duplicates' (ksPSpace s))"
  (ignore: getObject threadSet wp: setObject_ksInterrupt updateObject_default_inv
    simp:crunch_simps)


lemma invokeTCB_valid_duplicates'[wp]:
  "\<lbrace>invs' and sch_act_simple and ct_in_state' runnable' and tcb_inv_wf' ti and (\<lambda>s. vs_valid_duplicates' (ksPSpace s))\<rbrace>
     invokeTCB ti
   \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (case_tac ti, simp_all only:)
       apply (simp add: invokeTCB_def)
       apply wp
       apply (clarsimp simp: invs'_def valid_state'_def
                      dest!: global'_no_ex_cap)
      apply (simp add: invokeTCB_def)
      apply wp
      apply (clarsimp simp: invs'_def valid_state'_def
                     dest!: global'_no_ex_cap)
     apply (wp tc_valid_duplicates')
     apply (clarsimp split:option.splits)
    apply (simp add:invokeTCB_def | wp mapM_x_wp' | intro impI conjI)+
  done

lemma performInvocation_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s) \<and> invs' s \<and> sch_act_simple s
    \<and> valid_invocation' i s \<and> ct_active' s\<rbrace> 
  RetypeDecls_H.performInvocation isBlocking isCall i 
  \<lbrace>\<lambda>reply s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (clarsimp simp:performInvocation_def)
  apply (simp add:ct_in_state'_def)
  apply (rule hoare_name_pre_state)
  apply (rule hoare_pre)
  apply wpc
   apply (wp performArchInvocation_valid_duplicates' |simp)+
  apply (cases i)
  apply (clarsimp simp: simple_sane_strg sch_act_simple_def
                    ct_in_state'_def ct_active_runnable'[unfolded ct_in_state'_def]
                  | wp tcbinv_invs' arch_performInvocation_invs'
                  | rule conjI | erule active_ex_cap')+
  apply simp
  done

lemma hi_valid_duplicates'[wp]:
  "\<lbrace>invs' and sch_act_simple and ct_active' 
    and (\<lambda>s. vs_valid_duplicates' (ksPSpace s))\<rbrace>
      handleInvocation isCall isBlocking
   \<lbrace>\<lambda>r s. vs_valid_duplicates' (ksPSpace s) \<rbrace>"
  apply (simp add: handleInvocation_def split_def
                   ts_Restart_case_helper')
  apply (wp syscall_valid' setThreadState_nonqueued_state_update 
    rfk_invs' ct_in_state'_set | simp)+
    apply (fastforce simp add: tcb_at_invs' ct_in_state'_def 
                              simple_sane_strg
                              sch_act_simple_def
                       elim!: st_tcb'_weakenE st_tcb_ex_cap''
                        dest: st_tcb_at_idle_thread')+
  done

crunch valid_duplicates' [wp]: 
  activateIdleThread "(\<lambda>s. vs_valid_duplicates' (ksPSpace s))"
  (ignore: setNextPC threadSet simp:crunch_simps)

crunch valid_duplicates' [wp]: 
  tcbSchedAppend "(\<lambda>s. vs_valid_duplicates' (ksPSpace s))"
  (simp:crunch_simps wp:hoare_unless_wp)

lemma timerTick_valid_duplicates'[wp]: 
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
  timerTick \<lbrace>\<lambda>x s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add:timerTick_def decDomainTime_def)
   apply (wp hoare_drop_imps|wpc|simp)+
  done

lemma handleInterrupt_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. vs_valid_duplicates' (ksPSpace s)\<rbrace>
  handleInterrupt irq \<lbrace>\<lambda>r s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add: handleInterrupt_def)
  apply (rule hoare_pre)
   apply (wp sai_st_tcb' hoare_vcg_all_lift hoare_drop_imps
             threadSet_st_tcb_no_state getIRQState_inv haskell_fail_wp
          |wpc|simp)+
  done


crunch valid_duplicates' [wp]: 
  schedule "(\<lambda>s. vs_valid_duplicates' (ksPSpace s))"
  (ignore: setNextPC MachineOps.clearExMonitor threadSet simp:crunch_simps wp:findM_inv)

lemma activate_sch_valid_duplicates'[wp]:
  "\<lbrace>\<lambda>s. ct_in_state' activatable' s \<and> vs_valid_duplicates' (ksPSpace s)\<rbrace>
     activateThread \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add: activateThread_def getCurThread_def
             cong: if_cong Structures_H.thread_state.case_cong)
  apply (rule hoare_seq_ext [OF _ gets_sp])
  apply (rule hoare_seq_ext[where B="\<lambda>st s.  (runnable' or idle') st 
    \<and> vs_valid_duplicates' (ksPSpace s)"])
   apply (rule hoare_pre)
    apply (wp | wpc | simp add: setThreadState_runnable_simp)+
  apply (clarsimp simp: ct_in_state'_def cur_tcb'_def st_tcb_at_tcb_at'
                 elim!: st_tcb'_weakenE)
  done

crunch valid_duplicates'[wp]:
  receiveAsyncIPC "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"

crunch valid_duplicates'[wp]:
  receiveIPC "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"

crunch valid_duplicates'[wp]:
  deleteCallerCap "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"

crunch valid_duplicates'[wp]:
  handleReply "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"

crunch valid_duplicates'[wp]:
  handleYield "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
 (ignore: threadGet simp:crunch_simps wp:hoare_unless_wp)

crunch valid_duplicates'[wp]:
  "VSpace_H.handleVMFault" "\<lambda>s. vs_valid_duplicates' (ksPSpace s)"
 (ignore: getFAR getDFSR getIFSR simp:crunch_simps)

lemma hs_valid_duplicates'[wp]:
  "\<lbrace>invs' and ct_active' and sch_act_simple and (\<lambda>s. vs_valid_duplicates' (ksPSpace s))\<rbrace>
  handleSend blocking \<lbrace>\<lambda>r s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (rule validE_valid)
  apply (simp add: handleSend_def)
  apply (wp | simp)+
  done

lemma hc_valid_duplicates'[wp]:
  "\<lbrace>invs' and ct_active' and sch_act_simple and (\<lambda>s. vs_valid_duplicates' (ksPSpace s))\<rbrace>
     handleCall
   \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  by (simp add: handleCall_def |  wp)+

lemma hw_invs'[wp]:
  "\<lbrace>(\<lambda>s. vs_valid_duplicates' (ksPSpace s))\<rbrace> 
  handleWait \<lbrace>\<lambda>r s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add: handleWait_def cong: if_cong)
  apply (rule hoare_pre)
   apply wp
       apply ((wp | wpc | simp)+)[1]
      apply (rule_tac Q="\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)"

                   in hoare_post_impErr[rotated])

        apply (clarsimp simp: isCap_simps sch_act_sane_not)
       apply assumption
      apply (wp deleteCallerCap_nonz_cap)
  apply (auto elim: st_tcb_ex_cap'' st_tcb'_weakenE 
             dest!: st_tcb_at_idle_thread'
              simp: ct_in_state'_def sch_act_sane_def)
 done

lemma handleEvent_valid_duplicates':
  "\<lbrace>invs' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and
    sch_act_simple and (\<lambda>s. e \<noteq> Interrupt \<longrightarrow> ct_running' s)\<rbrace>
   handleEvent e
   \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (case_tac e, simp_all add: handleEvent_def)
      apply (case_tac syscall) 
            apply (wp handleReply_sane
              | simp add: active_from_running' simple_sane_strg
              | wpc)+
  done

lemma callKernel_valid_duplicates':
  "\<lbrace>invs' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and
    (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread) and
    (\<lambda>s. e \<noteq> Interrupt \<longrightarrow> ct_running' s)\<rbrace>
   callKernel e
   \<lbrace>\<lambda>rv s. vs_valid_duplicates' (ksPSpace s)\<rbrace>"
  apply (simp add: callKernel_def)
  apply (rule hoare_pre)
   apply (wp activate_invs' activate_sch_act schedule_sch
             schedule_sch_act_simple he_invs'
          | simp add: no_irq_getActiveIRQ)+
   apply (rule hoare_post_impErr)
     apply (rule valid_validE)
     prefer 2
     apply assumption
    apply (wp handleEvent_valid_duplicates')
   apply simp
  apply simp
  done

end
