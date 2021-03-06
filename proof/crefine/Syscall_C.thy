(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

theory Syscall_C
imports
  Interrupt_C
  Ipc_C
  Invoke_C
  Schedule_C
  Arch_C
begin

crunch sch_act_wf [wp]: replyFromKernel "\<lambda>s. sch_act_wf (ksSchedulerAction s) s"

context kernel_m begin

declare split_if [split del]

(* FIXME: should do this from the beginning *)
declare true_def [simp] false_def [simp]

lemma ccorres_If_False:
  "ccorres_underlying sr Gamm r xf arrel axf R R' hs b c
   \<Longrightarrow> ccorres_underlying sr Gamm r xf arrel axf
            (R and (\<lambda>_. \<not> P)) R' hs (If P a b) c"
  by (rule ccorres_gen_asm, simp)

definition
  one_on_true :: "bool \<Rightarrow> nat"
where
 "one_on_true P \<equiv> if P then 1 else 0"

lemma one_on_true_True[simp]: "one_on_true True = 1"
  by (simp add: one_on_true_def)

lemma one_on_true_eq_0[simp]: "(one_on_true P = 0) = (\<not> P)"
  by (simp add: one_on_true_def split: split_if)

lemma cap_cases_one_on_true_sum:
  "one_on_true (isZombie cap) + one_on_true (isArchObjectCap cap)
     + one_on_true (isThreadCap cap) + one_on_true (isCNodeCap cap)
     + one_on_true (isAsyncEndpointCap cap) + one_on_true (isEndpointCap cap)
     + one_on_true (isUntypedCap cap) + one_on_true (isReplyCap cap)
     + one_on_true (isIRQControlCap cap) + one_on_true (isIRQHandlerCap cap)
     + one_on_true (isNullCap cap) + one_on_true (isDomainCap cap) = 1"
  by (cases cap, simp_all add: isCap_simps)

lemma performInvocation_Endpoint_ccorres:
  "ccorres (K (K \<bottom>) \<currency> dc) (liftxf errstate id (K ()) ret__unsigned_long_')
       (invs' and st_tcb_at' simple' thread and ep_at' epptr
              and sch_act_sane and (\<lambda>s. thread = ksCurThread s
              \<and> (\<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p))))
       (UNIV \<inter> {s. block_' s = from_bool blocking}
             \<inter> {s. call_' s = from_bool do_call}
             \<inter> {s. badge_' s = badge}
             \<inter> {s. canGrant_' s = from_bool canGrant}
             \<inter> {s. ep_' s = ep_Ptr epptr}
             \<inter> \<lbrace>badge && mask 28 = badge\<rbrace>) []
     (liftE (sendIPC blocking do_call badge canGrant thread epptr))
     (Call performInvocation_Endpoint_'proc)"
  apply cinit
   apply (ctac add: sendIPC_ccorres)
     apply (simp add: return_returnOk)
     apply (rule ccorres_return_CE, simp+)[1]
    apply wp
   apply simp
   apply (vcg exspec=sendIPC_modifies)
  apply (clarsimp simp add: rf_sr_ksCurThread sch_act_sane_not)
  done

lemma performInvocation_AsyncEndpoint_ccorres:
  "ccorres (K (K \<bottom>) \<currency> dc) (liftxf errstate id (K ()) ret__unsigned_long_')
       invs'
       (UNIV \<inter> {s. aep_' s = aep_Ptr aepptr}
             \<inter> {s. badge_' s = badge}
             \<inter> {s. message_' s = message}) []
     (liftE (sendAsyncIPC aepptr badge message))
     (Call performInvocation_AsyncEndpoint_'proc)"
  apply cinit
   apply (ctac add: sendAsyncIPC_ccorres)
     apply (simp add: return_returnOk)
     apply (rule ccorres_return_CE, simp+)[1]
    apply wp
   apply simp
   apply (vcg exspec=sendAsyncIPC_modifies)
  apply simp
  done

lemma performInvocation_Reply_ccorres:
  "ccorres (K (K \<bottom>) \<currency> dc) (liftxf errstate id (K ()) ret__unsigned_long_')
       (invs' and tcb_at' receiver and st_tcb_at' active' sender and sch_act_simple
              and (\<lambda>s. ksCurThread s = sender))
       (UNIV \<inter> {s. thread_' s = tcb_ptr_to_ctcb_ptr receiver}
             \<inter> {s. slot_' s = cte_Ptr slot}) []
     (liftE (doReplyTransfer sender receiver slot))
     (Call performInvocation_Reply_'proc)"
  apply cinit
   apply (ctac add: doReplyTransfer_ccorres)
     apply (simp add: return_returnOk)
     apply (rule ccorres_return_CE, simp+)[1]
    apply wp
   apply simp
   apply (vcg exspec=doReplyTransfer_modifies)
  apply (simp add: rf_sr_ksCurThread)
  apply (auto simp: isReply_def elim!: st_tcb'_weakenE)
  done

lemma decodeInvocation_ccorres:
  "interpret_excaps extraCaps' = excaps_map extraCaps
  \<Longrightarrow>
   ccorres (intr_and_se_rel \<currency> dc) (liftxf errstate id (K ()) ret__unsigned_long_')
       (invs' and (\<lambda>s. ksCurThread s = thread) and ct_active' and sch_act_simple
              and valid_cap' cp and (\<lambda>s. \<forall>x \<in> zobj_refs' cp. ex_nonz_cap_to' x s)
              and (excaps_in_mem extraCaps \<circ> ctes_of)
              and cte_wp_at' (diminished' cp \<circ> cteCap) slot
              and (\<lambda>s. \<forall>v \<in> set extraCaps. ex_cte_cap_wp_to' isCNodeCap (snd v) s)
              and (\<lambda>s. \<forall>v \<in> set extraCaps. s \<turnstile>' fst v \<and> cte_at' (snd v) s)
              and (\<lambda>s. \<forall>v \<in> set extraCaps. \<forall>y \<in> zobj_refs' (fst v). ex_nonz_cap_to' y s)
              and (\<lambda>s. \<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p))
              and sysargs_rel args buffer)
       (UNIV \<inter> {s. call_' s = from_bool isCall}
                   \<inter> {s. block_' s = from_bool isBlocking}
                   \<inter> {s. call_' s = from_bool isCall}
                   \<inter> {s. block_' s = from_bool isBlocking}
                   \<inter> {s. label_' s = label}
                   \<inter> {s. unat (length_' s) = length args}
                   \<inter> {s. capIndex_' s = cptr}
                   \<inter> {s. slot_' s = cte_Ptr slot}
                   \<inter> {s. extraCaps_' s = extraCaps'}
                   \<inter> {s. ccap_relation cp (cap_' s)}
                   \<inter> {s. buffer_' s = option_to_ptr buffer}) []
       (decodeInvocation label args cptr slot cp extraCaps
              >>= invocationCatch thread isBlocking isCall id)
       (Call decodeInvocation_'proc)"
  apply (cinit' lift: call_' block_' label_' length_'
                      capIndex_' slot_' extraCaps_' cap_' buffer_')
   apply csymbr
   apply (simp add: cap_get_tag_isCap decodeInvocation_def
              cong: if_cong StateSpace.state.fold_congs
                    globals.fold_congs
               del: Collect_const)
   apply (cut_tac cap=cp in cap_cases_one_on_true_sum)
   apply (rule ccorres_Cond_rhs_Seq)
    apply (simp add: Let_def isArchCap_T_isArchObjectCap 
                     liftME_invocationCatch from_bool_neq_0)
    apply (rule ccorres_split_throws)
     apply (rule ccorres_trim_returnE)
       apply simp
      apply simp
     apply (rule ccorres_call, rule Arch_decodeInvocation_ccorres [where buffer=buffer])
        apply assumption
       apply simp+
    apply (vcg exspec=Arch_decodeInvocation_modifies)
   apply simp
   apply csymbr
   apply (simp add: cap_get_tag_isCap del: Collect_const)
   apply (rule ccorres_Cond_rhs)
    apply (simp add: invocationCatch_def throwError_bind)
    apply (rule syscall_error_throwError_ccorres_n)
    apply (simp add: syscall_error_to_H_cases)
   apply (rule ccorres_Cond_rhs)
    apply (simp add: invocationCatch_def throwError_bind)
    apply (rule syscall_error_throwError_ccorres_n)
    apply (simp add: syscall_error_to_H_cases)
   apply (rule ccorres_Cond_rhs)
    apply (simp add: if_to_top_of_bind)
    apply (rule ccorres_rhs_assoc)+
    apply csymbr
    apply (rule ccorres_if_cond_throws2[where Q=\<top> and Q'=\<top>])
       apply (clarsimp simp: isCap_simps Collect_const_mem)
       apply (frule cap_get_tag_isCap_unfolded_H_cap)
       apply (drule(1) cap_get_tag_to_H)
       apply (clarsimp simp: to_bool_def)
      apply (simp add: throwError_bind invocationCatch_def)
      apply (rule syscall_error_throwError_ccorres_n)
      apply (simp add: syscall_error_to_H_cases)
     apply (simp add: returnOk_bind ccorres_invocationCatch_Inr
                      performInvocation_def bind_assoc liftE_bindE)
     apply (ctac add: setThreadState_ccorres)
       apply csymbr
       apply csymbr
       apply csymbr
       apply (rule ccorres_pre_getCurThread)
       apply (simp only: liftE_bindE[symmetric])
       apply (ctac add: performInvocation_Endpoint_ccorres)
          apply (rule ccorres_alternative2)
          apply (rule ccorres_return_CE, simp+)[1]
         apply (rule ccorres_return_C_errorE, simp+)[1]
        apply wp
       apply simp
       apply (vcg exspec=performInvocation_Endpoint_modifies)
      apply simp
      apply (rule hoare_use_eq[where f=ksCurThread])
       apply (wp sts_invs_minor' sts_st_tcb_at'_cases
                 setThreadState_ct' hoare_vcg_all_lift sts_ksQ')
     apply simp
     apply (vcg exspec=setThreadState_modifies)
    apply vcg
   apply (rule ccorres_Cond_rhs)
    apply (rule ccorres_rhs_assoc)+
    apply (csymbr, csymbr)
    apply (simp add: if_to_top_of_bind Collect_const[symmetric]
                del: Collect_const)
    apply (rule ccorres_if_cond_throws2[where Q=\<top> and Q'=\<top>])
       apply (clarsimp simp:  isCap_simps Collect_const_mem)
       apply (frule cap_get_tag_isCap_unfolded_H_cap)
       apply (drule(1) cap_get_tag_to_H)
       apply (clarsimp simp: to_bool_def)
      apply (simp add: throwError_bind invocationCatch_def)
      apply (rule syscall_error_throwError_ccorres_n)
      apply (simp add: syscall_error_to_H_cases)
     apply (rule ccorres_add_return,
            rule_tac xf'=msg_' and r'="\<lambda>rv rv'. rv'=(case args of [] \<Rightarrow> 0 | x # xs \<Rightarrow> x)"
               in ccorres_split_nothrow)
         apply (rule ccorres_Cond_rhs)
          apply (rule ccorres_from_vcg[where P=\<top> and P'=UNIV])
          apply (rule allI, rule conseqPre, vcg)
          apply (simp add: return_def)
         apply (rule ccorres_add_return, rule iffD1 [OF ccorres_seq_skip'])
         apply (ctac add: getSyscallArg_ccorres_foo[where args=args and n=0 and buffer=buffer])
           apply (rule ccorres_return_Skip')
          apply wp
         apply simp
         apply (subgoal_tac "args \<noteq> []")
          apply (simp add: list_case_helper hd_conv_nth)
          apply (vcg exspec=getSyscallArg_modifies)
         apply (clarsimp simp: unat_eq_0)
        apply ceqv
       apply (simp add: returnOk_bind ccorres_invocationCatch_Inr
                        performInvocation_def bindE_assoc)
       apply (simp add: liftE_bindE)
       apply (ctac add: setThreadState_ccorres)
         apply csymbr
         apply csymbr
         apply (simp only: liftE_bindE[symmetric])
         apply (ctac(no_vcg) add: performInvocation_AsyncEndpoint_ccorres)
           apply (rule ccorres_alternative2)
           apply (rule ccorres_return_CE, simp+)[1]
          apply (rule ccorres_return_C_errorE, simp+)[1]
         apply wp
        apply (wp sts_invs_minor')
       apply simp
       apply (vcg exspec=setThreadState_modifies)
      apply wp
     apply simp
     apply (vcg exspec=getSyscallArg_modifies)
    apply vcg
   apply (rule ccorres_Cond_rhs)
    apply (simp add: if_to_top_of_bind)
    apply (rule ccorres_rhs_assoc)+
    apply csymbr
    apply (rule ccorres_if_cond_throws2[where Q=\<top> and Q'=\<top>])
       apply (clarsimp simp: isCap_simps Collect_const_mem)
       apply (frule cap_get_tag_isCap_unfolded_H_cap)
       apply (clarsimp simp: cap_get_tag_ReplyCap to_bool_def)
      apply (simp add: throwError_bind invocationCatch_def)
      apply (rule syscall_error_throwError_ccorres_n)
      apply (simp add: syscall_error_to_H_cases)
     apply (simp add: returnOk_bind ccorres_invocationCatch_Inr
                      performInvocation_def liftE_bindE
                      bind_assoc)
     apply (ctac add: setThreadState_ccorres)
       apply csymbr
       apply (rule ccorres_pre_getCurThread)
       apply (simp only: liftE_bindE[symmetric])
       apply (ctac add: performInvocation_Reply_ccorres)
          apply (rule ccorres_alternative2)
          apply (rule ccorres_return_CE, simp+)[1]
         apply (rule ccorres_return_C_errorE, simp+)[1]
        apply wp
       apply simp
       apply (vcg exspec=performInvocation_Reply_modifies)
      apply (simp add: cur_tcb'_def[symmetric])
      apply (rule_tac R="\<lambda>rv s. ksCurThread s = thread" in hoare_post_add)
      apply (simp cong: conj_cong)
      apply (wp sts_invs_minor' sts_st_tcb_at'_cases)
     apply simp
     apply (vcg exspec=setThreadState_modifies)
    apply vcg
   apply (rule ccorres_Cond_rhs)
    apply (simp add: if_to_top_of_bind)
     apply (rule ccorres_trim_returnE, simp+)
     apply (simp add: liftME_invocationCatch o_def)
     apply (rule ccorres_call, rule decodeTCBInvocation_ccorres)
        apply assumption
       apply (simp+)[3]
   apply (rule ccorres_Cond_rhs)
    apply (rule ccorres_trim_returnE, simp+)
    apply (simp add: liftME_invocationCatch o_def)
    apply (rule ccorres_call,
           erule decodeDomainInvocation_ccorres[unfolded o_def],
           simp+)[1]
   apply (rule ccorres_Cond_rhs)
    apply (simp add: if_to_top_of_bind)
    apply (rule ccorres_trim_returnE, simp+)
    apply (simp add: liftME_invocationCatch o_def)
    apply (rule ccorres_call,
           erule decodeCNodeInvocation_ccorres[unfolded o_def],
           simp+)[1]
   apply (rule ccorres_Cond_rhs)
    apply simp
    apply (rule ccorres_trim_returnE, simp+)
    apply (simp add: liftME_invocationCatch)
    apply (rule ccorres_call,
           erule decodeUntypedInvocation_ccorres, simp+)[1]
   apply (rule ccorres_Cond_rhs)
    apply (simp add: liftME_invocationCatch)
    apply (rule ccorres_trim_returnE, simp+)
    apply (rule ccorres_call, erule decodeIRQControlInvocation_ccorres,
           simp+)[1]
   apply (rule ccorres_Cond_rhs)
    apply (simp add: Let_def liftME_invocationCatch)
    apply (rule ccorres_rhs_assoc)+
    apply csymbr
    apply (rule ccorres_trim_returnE, simp+)
    apply (rule ccorres_call,
           erule decodeIRQHandlerInvocation_ccorres, simp+)
   apply (rule ccorres_inst[where P=\<top> and P'=UNIV])
   apply (simp add: isArchCap_T_isArchObjectCap one_on_true_def from_bool_0)
  apply (rule conjI)
   apply (clarsimp simp: tcb_at_invs' ct_in_state'_def
                         simple_sane_strg)
   apply (clarsimp simp: cte_wp_at_ctes_of valid_cap'_def isCap_simps from_bool_neq_0
                         unat_eq_0 sysargs_rel_n_def n_msgRegisters_def valid_tcb_state'_def
             | rule conjI | erule st_tcb'_weakenE disjE
             | drule st_tcb_at_idle_thread')+
   apply fastforce
  apply (simp add: cap_lift_capEPBadge_mask_eq)
  apply (clarsimp simp: rf_sr_ksCurThread Collect_const_mem
                        cap_get_tag_isCap "StrictC'_thread_state_defs")
  apply (frule word_unat.Rep_inverse')
  apply (simp add: cap_get_tag_isCap[symmetric] cap_get_tag_ReplyCap)
  apply (rule conjI)
   apply (simp add: cap_get_tag_isCap)
   apply (clarsimp simp: isCap_simps cap_get_tag_to_H from_bool_neq_0)
  apply (insert ccap_relation_IRQHandler_mask, elim meta_allE, drule(1) meta_mp)
  apply (rule conjI | clarsimp
              | drule(1) cap_get_tag_to_H
              | simp add: cap_endpoint_cap_lift_def
                          cap_async_endpoint_cap_lift_def
                          cap_reply_cap_lift_def cap_lift_endpoint_cap
                          cap_lift_async_endpoint_cap cap_lift_reply_cap
                          from_bool_to_bool_and_1 word_size
                          order_le_less_trans[OF word_and_le1]
                          mask_eq_iff_w2p word_size ucast_ucast_mask
                          isCap_simps
                          mask_eq_iff_w2p[THEN trans[OF eq_commute]])+
  done

lemma ccorres_Call_Seq:
  "\<lbrakk> \<Gamma> f = Some v; ccorres r xf P P' hs a (v ;; c) \<rbrakk>
       \<Longrightarrow> ccorres r xf P P' hs a (Call f ;; c)"
  apply (erule ccorres_semantic_equivD1)
  apply (rule semantic_equivI)
  apply (auto elim!: exec_elim_cases intro: exec.intros)
  done

lemma liftME_map_mapME:
  "liftME (map f) (mapME m xs)
      = mapME (liftME f o m) xs"
  apply (rule sym)
  apply (induct xs)
   apply (simp add: liftME_def)
  apply (simp add: mapME_Cons liftME_def bindE_assoc)
  done

lemma wordFromRights_mask_0:
  "wordFromRights rghts && ~~ mask 4 = 0"
  apply (simp add: wordFromRights_def word_ao_dist word_or_zero
            split: cap_rights.split)
  apply (simp add: mask_def split: split_if)
  done

lemma wordFromRights_mask_eq:
  "wordFromRights rghts && mask 4 = wordFromRights rghts"
  apply (cut_tac x="wordFromRights rghts" and y="mask 4" and z="~~ mask 4"
             in word_bool_alg.conj_disj_distrib)
  apply (simp add: wordFromRights_mask_0)
  done

lemma loadWordUser_user_word_at:
  "\<lbrace>\<lambda>s. \<forall>rv. user_word_at rv x s \<longrightarrow> Q rv s\<rbrace> loadWordUser x \<lbrace>Q\<rbrace>"
  apply (simp add: loadWordUser_def user_word_at_def
                   doMachineOp_def split_def)
  apply wp
  apply (clarsimp simp: pointerInUserData_def
                        loadWord_def in_monad
                        is_aligned_mask)
  done

lemma mapM_loadWordUser_user_words_at:
  "\<lbrace>\<lambda>s. \<forall>rv. (\<forall>x < length xs. user_word_at (rv ! x) (xs ! x) s)
              \<and> length rv = length xs \<longrightarrow> Q rv s\<rbrace>
    mapM loadWordUser xs \<lbrace>Q\<rbrace>"
  apply (induct xs arbitrary: Q)
   apply (simp add: mapM_def sequence_def)
   apply wp
  apply (simp add: mapM_Cons)
  apply wp
   apply assumption
  apply (wp loadWordUser_user_word_at)
  apply clarsimp
  apply (drule spec, erule mp)
  apply clarsimp
  apply (case_tac x)
   apply simp
  apply simp
  done

lemma getSlotCap_slotcap_in_mem:
  "\<lbrace>\<top>\<rbrace> getSlotCap slot \<lbrace>\<lambda>cap s. slotcap_in_mem cap slot (ctes_of s)\<rbrace>"
  apply (simp add: getSlotCap_def)
  apply (wp getCTE_wp')
  apply (clarsimp simp: cte_wp_at_ctes_of slotcap_in_mem_def)
  done

lemma lookupExtraCaps_excaps_in_mem[wp]:
  "\<lbrace>\<top>\<rbrace> lookupExtraCaps thread buffer info \<lbrace>\<lambda>rv s. excaps_in_mem rv (ctes_of s)\<rbrace>,-"
  apply (simp add: excaps_in_mem_def lookupExtraCaps_def lookupCapAndSlot_def
                   split_def)
  apply (wp mapME_set)
      apply (wp getSlotCap_slotcap_in_mem | simp)+
    apply (rule hoare_pre, wp, simp)
   apply (simp add:hoare_TrueI)+
  done

lemma getCurThread_ccorres:
  "ccorres (op = \<circ> tcb_ptr_to_ctcb_ptr) thread_'
       \<top> UNIV hs getCurThread (\<acute>thread :== \<acute>ksCurThread)"
  apply (rule ccorres_from_vcg)
  apply (rule allI, rule conseqPre, vcg)
  apply (clarsimp simp: getCurThread_def simpler_gets_def
                        rf_sr_ksCurThread)
  done

lemma getMessageInfo_ccorres:
  "ccorres (\<lambda>rv rv'. rv = messageInfoFromWord rv') ret__unsigned_long_' \<top>
       (UNIV \<inter> {s. thread_' s = tcb_ptr_to_ctcb_ptr thread}
             \<inter> {s. reg_' s = register_from_H State_H.msgInfoRegister}) []
       (getMessageInfo thread) (Call getRegister_'proc)"
  apply (simp add: getMessageInfo_def liftM_def[symmetric]
                   ccorres_liftM_simp)
  apply (rule ccorres_rel_imp, rule ccorres_guard_imp2, rule getRegister_ccorres)
   apply simp
  apply simp
  done

lemma messageInfoFromWord_spec:
  "\<forall>s. \<Gamma> \<turnstile> {s} Call messageInfoFromWord_'proc
            {s'. message_info_lift (ret__struct_message_info_C_' s')
                  = mi_from_H (messageInfoFromWord (w_' s))}"
  apply (rule allI, rule conseqPost, rule messageInfoFromWord_spec[rule_format])
   apply simp_all
  apply (clarsimp simp: message_info_lift_def mi_from_H_def
                        messageInfoFromWord_def Let_def
                        Types_H.msgLengthBits_def Types_H.msgExtraCapBits_def
                        Types_H.msgMaxExtraCaps_def shiftL_nat)
  apply (fold mask_def[where n=20, simplified])
  apply (rule less_mask_eq)
  apply (rule shiftr_less_t2n')
   apply simp
  apply simp
  done

lemma threadGet_tcbIpcBuffer_ccorres [corres]:
  "ccorres (op =) w_bufferPtr_' (tcb_at' tptr) UNIV hs 
           (threadGet tcbIPCBuffer tptr)
           (Guard C_Guard \<lbrace>hrs_htd \<acute>t_hrs \<Turnstile>\<^sub>t (Ptr &(tcb_ptr_to_ctcb_ptr tptr\<rightarrow>
                                  [''tcbIPCBuffer_C''])::word32 ptr)\<rbrace>
               (\<acute>w_bufferPtr :==
                  h_val (hrs_mem \<acute>t_hrs)
                   (Ptr &(tcb_ptr_to_ctcb_ptr tptr\<rightarrow>[''tcbIPCBuffer_C''])::word32 ptr)))"
  apply (rule ccorres_guard_imp2)
   apply (rule ccorres_add_return2)
   apply (rule ccorres_pre_threadGet)
   apply (rule_tac P = "obj_at' (\<lambda>tcb. tcbIPCBuffer tcb = x) tptr" and
                   P'="{s'. \<exists>ctcb.
          cslift s' (tcb_ptr_to_ctcb_ptr tptr) = Some ctcb \<and>
                 tcbIPCBuffer_C ctcb = x }" in ccorres_from_vcg)
   apply (rule allI, rule conseqPre, vcg)
   apply clarsimp
   apply (clarsimp simp: return_def typ_heap_simps')
  apply (clarsimp simp: obj_at'_def ctcb_relation_def)
  done 

lemma handleInvocation_def2:
  "handleInvocation isCall isBlocking =
   do thread \<leftarrow> getCurThread;
      info \<leftarrow> getMessageInfo thread;
      ptr \<leftarrow> asUser thread (getRegister State_H.capRegister);
      v \<leftarrow> (doE (cap, slot) \<leftarrow> capFaultOnFailure ptr False (lookupCapAndSlot thread ptr);
          buffer \<leftarrow> withoutFailure (VSpace_H.lookupIPCBuffer False thread);
          extracaps \<leftarrow> lookupExtraCaps thread buffer info;
          returnOk (slot, cap, extracaps, buffer)
      odE);
      case v of Inl f \<Rightarrow> liftE (when isBlocking (handleFault thread f))
        | Inr (slot, cap, extracaps, buffer) \<Rightarrow>
               do args \<leftarrow> getMRs thread buffer info;
                  v' \<leftarrow> do v \<leftarrow> RetypeDecls_H.decodeInvocation (msgLabel info) args ptr slot cap extracaps;
                               invocationCatch thread isBlocking isCall id v od;
                  case v' of Inr _ \<Rightarrow> liftE (replyOnRestart thread [] isCall)
                           | Inl (Inl syserr) \<Rightarrow> liftE (when isCall (replyFromKernel thread
                                                                   (msgFromSyscallError syserr)))
                           | Inl (Inr preempt) \<Rightarrow> throwError preempt
               od
   od"
  apply (simp add: handleInvocation_def Syscall_H.syscall_def runErrorT_def
                   liftE_bindE cong: sum.case_cong)
  apply (rule ext, (rule bind_apply_cong [OF refl])+)
  apply (clarsimp simp: bind_assoc split: sum.split)
  apply (rule bind_apply_cong [OF refl])+
  apply (clarsimp simp: invocationCatch_def throwError_bind
                        liftE_bindE bind_assoc
                 split: sum.split)
  apply (rule bind_apply_cong [OF refl])+
  apply (simp add: bindE_def bind_assoc)
  apply (rule bind_apply_cong [OF refl])+
  apply (clarsimp simp: lift_def throwError_bind returnOk_bind split: sum.split)
  apply (simp cong: bind_cong add: ts_Restart_case_helper')
  apply (simp add: when_def[symmetric] replyOnRestart_def[symmetric])
  apply (simp add: liftE_def replyOnRestart_twice alternative_bind 
                   alternative_refl split: split_if)
  done

lemma thread_state_to_tsType_eq_Restart:
  "(thread_state_to_tsType ts = scast ThreadState_Restart)
       = (ts = Restart)"
  by (cases ts, simp_all add: "StrictC'_thread_state_defs")

lemma wordFromMessageInfo_spec:
  "\<forall>s. \<Gamma>\<turnstile> {s} Call wordFromMessageInfo_'proc
      {s'. \<forall>mi. message_info_lift (mi_' s) = mi_from_H mi
                   \<longrightarrow> ret__unsigned_long_' s' = wordFromMessageInfo mi}" 
  apply (rule allI, rule conseqPost, rule wordFromMessageInfo_spec2[rule_format])
   prefer 2
   apply simp
  apply (clarsimp simp: wordFromMessageInfo_def Let_def Types_H.msgExtraCapBits_def
                        Types_H.msgLengthBits_def Types_H.msgMaxExtraCaps_def
                        shiftL_nat)
  apply (clarsimp simp: mi_from_H_def message_info_lift_def
                        word_bw_comms word_bw_assocs word_bw_lcs)
  done

lemma handleDoubleFault_ccorres:
  "ccorres dc xfdc (invs' and  tcb_at' tptr and (\<lambda>s. weak_sch_act_wf (ksSchedulerAction s) s) and
        sch_act_not tptr and (\<lambda>s. \<forall>p. tptr \<notin> set (ksReadyQueues s p)))
      (UNIV \<inter> {s. tptr_' s = tcb_ptr_to_ctcb_ptr tptr}) 
      [] (handleDoubleFault tptr ex1 ex2)
         (Call handleDoubleFault_'proc)"
  apply (cinit lift: tptr_')
   apply (subst ccorres_seq_skip'[symmetric])
   apply (ctac (no_vcg))
    apply (rule ccorres_symb_exec_l)
       apply (rule ccorres_return_Skip)
      apply (wp asUser_inv getRestartPC_inv)
    apply (rule empty_fail_asUser)
    apply (simp add: getRestartPC_def)
   apply wp
  apply clarsimp
  apply (simp add: ThreadState_Inactive_def)
  apply (fastforce simp: valid_tcb_state'_def)
  done

lemma cap_case_EndpointCap_CanSend_CanGrant:
  "(case cap of EndpointCap v0 v1 True v3 True \<Rightarrow> f v0 v1 v3  
              | _ \<Rightarrow> g)
   = (if (isEndpointCap cap \<and> capEPCanSend cap \<and> capEPCanGrant cap)
      then f (capEPPtr cap)  (capEPBadge cap) (capEPCanReceive cap) 
      else g)"
  by (simp add: isCap_simps
           split: capability.split bool.split)

lemma threadGet_tcbFaultHandler_ccorres [corres]:
  "ccorres (op =) handlerCPtr_' (tcb_at' tptr) UNIV hs 
           (threadGet tcbFaultHandler tptr)
           (Guard C_Guard \<lbrace>hrs_htd \<acute>t_hrs \<Turnstile>\<^sub>t (tcb_ptr_to_ctcb_ptr tptr)\<rbrace>
               (\<acute>handlerCPtr :==
                  h_val (hrs_mem \<acute>t_hrs)
                   (Ptr &(tcb_ptr_to_ctcb_ptr tptr\<rightarrow>[''tcbFaultHandler_C''])::word32 ptr)))"
  apply (rule ccorres_guard_imp2)
   apply (rule ccorres_add_return2)
   apply (rule ccorres_pre_threadGet)
   apply (rule_tac P = "obj_at' (\<lambda>tcb. tcbFaultHandler tcb = x) tptr" and
                   P'="{s'. \<exists> ctcb.
          cslift s' (tcb_ptr_to_ctcb_ptr tptr) = Some ctcb \<and>
                 tcbFaultHandler_C ctcb = x }" in ccorres_from_vcg)
   apply (rule allI, rule conseqPre, vcg)
   apply clarsimp
   apply (clarsimp simp: return_def typ_heap_simps')
  apply (clarsimp simp: obj_at'_def ctcb_relation_def)
done



lemma sendFaultIPC_ccorres:
  "ccorres  (cfault_rel2 \<currency> dc) (liftxf errstate id (K ()) ret__unsigned_long_')
      (invs' and st_tcb_at' simple' tptr and sch_act_not tptr and
       (\<lambda>s. \<forall>p. tptr \<notin> set (ksReadyQueues s p)))
      (UNIV \<inter> {s. (cfault_rel (Some fault) (fault_lift(current_fault_' (globals s)))
                       (lookup_fault_lift(current_lookup_fault_' (globals s))))}
            \<inter> {s. tptr_' s = tcb_ptr_to_ctcb_ptr tptr}) 
      [] (sendFaultIPC tptr fault)
         (Call sendFaultIPC_'proc)"
  apply (cinit lift: tptr_' cong: call_ignore_cong)
   apply (simp add: liftE_bindE del:Collect_const cong:call_ignore_cong)
   apply (rule ccorres_symb_exec_r)
     apply (rule ccorres_split_nothrow)
          apply (rule threadGet_tcbFaultHandler_ccorres)
         apply ceqv

       apply (rule_tac  xf'=lu_ret___struct_lookupCap_ret_C_' 
              in  ccorres_split_nothrow_callE)
                apply (rule capFaultOnFailure_ccorres)
                apply (rule lookupCap_ccorres) 
               apply simp
              apply simp
             apply simp
            apply simp
           apply ceqv
          apply clarsimp
          apply csymbr+

          apply (simp add: cap_case_EndpointCap_CanSend_CanGrant) 

          apply (rule ccorres_rhs_assoc2) 
        
          apply (rule ccorres_symb_exec_r)
            apply (rule_tac Q=\<top>  
                        and Q'="\<lambda>s'.
                ( ret__int_' s' = 
                (if ( (cap_get_tag (lookupCap_ret_C.cap_C rv'a) = scast cap_endpoint_cap)  \<and>
                     (capCanSend_CL (cap_endpoint_cap_lift (lookupCap_ret_C.cap_C rv'a)))\<noteq>0 \<and>
                     (capCanGrant_CL (cap_endpoint_cap_lift (lookupCap_ret_C.cap_C rv'a)))\<noteq>0)  
                      then 1 else 0))"
                    in  ccorres_cond_both')
              apply clarsimp
              apply (frule cap_get_tag_isCap(4)[symmetric], 
                     clarsimp simp: cap_get_tag_EndpointCap to_bool_def
                     split:if_splits)

             apply (rule ccorres_rhs_assoc)
             apply (rule ccorres_rhs_assoc)
             apply (rule ccorres_rhs_assoc)
             apply (simp add: liftE_def bind_assoc)

             apply (rule_tac ccorres_split_nothrow_novcg)
                 apply (rule_tac P=\<top> and P'=invs' 
                          and R="{s.  
                        (cfault_rel (Some fault) 
                        (fault_lift(current_fault_' (globals s)))
                         (lookup_fault_lift(original_lookup_fault_'  s)))}"
                          in threadSet_ccorres_lemma4) 
                  apply vcg
                 apply (clarsimp simp: typ_heap_simps')
                 apply (intro conjI allI impI)
                  apply (simp add: typ_heap_simps rf_sr_def)
                  apply (rule rf_sr_tcb_update_no_queue2[unfolded rf_sr_def, simplified], 
                              assumption+)
                         apply (simp add: typ_heap_simps)+
                   apply (rule ball_tcb_cte_casesI, simp+)
                  apply (simp add: ctcb_relation_def cthread_state_relation_def )
                  apply (case_tac "tcbState tcb", simp+)
                 apply (simp add: rf_sr_def)
                 apply (rule rf_sr_tcb_update_no_queue2[unfolded rf_sr_def, simplified], 
                        assumption+)
                        apply (simp add: typ_heap_simps)+
                  apply (rule ball_tcb_cte_casesI, simp+)
                 apply (simp add: ctcb_relation_def cthread_state_relation_def )
                 apply (rule conjI)
                  apply (case_tac "tcbState tcb", simp+)
                 apply (simp add: cfault_rel_def)
                 apply (clarsimp)
                 apply (clarsimp simp: fault_lift_def Let_def is_cap_fault_def
                                 split: split_if_asm)
                apply ceqv

               apply csymbr
               apply csymbr
               apply (ctac (no_vcg) add: sendIPC_ccorres)
                apply (ctac (no_vcg) add: ccorres_return_CE [unfolded returnOk_def comp_def])
               apply wp
              apply (wp threadSet_st_tcb_no_state threadSet_invs_trivial threadSet_typ_at_lifts
                     | simp)+

             apply (clarsimp simp: guard_is_UNIV_def) 
             apply (frule cap_get_tag_isCap(4)[symmetric])
             apply (clarsimp simp: cap_get_tag_EndpointCap to_bool_def)
             apply (drule cap_get_tag_isCap(4) [symmetric])
             apply (clarsimp simp: isCap_simps cap_endpoint_cap_lift cap_lift_capEPBadge_mask_eq)

            apply clarsimp
            apply (rule_tac P=\<top> and P'=UNIV 
                      in ccorres_from_vcg_throws)            
            apply clarsimp
            apply (clarsimp simp add: throwError_def throw_def return_def)   
            apply (rule conseqPre, vcg)
            apply (clarsimp simp: EXCEPTION_FAULT_def EXCEPTION_NONE_def)
            apply (simp add: cfault_rel2_def cfault_rel_def EXCEPTION_FAULT_def)
            apply (simp add: fault_cap_fault_lift)
            apply (simp add: lookup_fault_missing_capability_lift is_cap_fault_def)

           apply vcg

          apply (clarsimp simp: if_1_0_0)
          apply (rule conseqPre, vcg)
          apply clarsimp

         apply clarsimp
         apply (rule ccorres_split_throws)
          apply (rule_tac P=\<top> and P'="{x. errstate x= err'}"
                    in ccorres_from_vcg_throws)            
          apply clarsimp
          apply (clarsimp simp add: throwError_def throw_def return_def)   
          apply (rule conseqPre, vcg)
          apply (clarsimp simp: EXCEPTION_FAULT_def EXCEPTION_NONE_def)
          apply (simp add: cfault_rel2_def cfault_rel_def EXCEPTION_FAULT_def)
          apply (simp add: fault_cap_fault_lift is_cap_fault_def)
          apply (erule lookup_failure_rel_fault_lift [rotated, unfolded EXCEPTION_NONE_def, simplified], 
                 assumption)

         apply vcg
        apply (clarsimp simp: inQ_def)
        apply (rule_tac Q="\<lambda>a b. invs' b \<and> st_tcb_at' simple' tptr b
                              \<and> sch_act_not tptr b \<and> valid_cap' a b
                              \<and> (\<forall>p. tptr \<notin> set (ksReadyQueues b p))"
                 and E="\<lambda> _. \<top>"
                 in hoare_post_impErr)
          apply (wp)
         apply (clarsimp simp: isCap_simps)
         apply (clarsimp simp: valid_cap'_def st_tcb_at')
        apply simp
      
       apply (clarsimp simp: if_1_0_0) 
       apply (vcg exspec=lookupCap_modifies)
       apply clarsimp
      apply wp
     apply (clarsimp simp: if_1_0_0)
     apply (vcg)

    apply (clarsimp, vcg)
   apply (rule conseqPre, vcg)
   apply clarsimp   
  apply (clarsimp simp: if_1_0_0) 
  apply fastforce
  done

lemma handleFault_ccorres:
  "ccorres dc xfdc (invs' and st_tcb_at' simple' t and
        sch_act_not t and (\<lambda>s. \<forall>p. t \<notin> set (ksReadyQueues s p)))
      (UNIV \<inter> {s. (cfault_rel (Some flt) (fault_lift(current_fault_' (globals s)))
                       (lookup_fault_lift(current_lookup_fault_' (globals s))) )}
            \<inter> {s. tptr_' s = tcb_ptr_to_ctcb_ptr t})
      [] (handleFault t flt)
         (Call handleFault_'proc)"
  apply (cinit lift: tptr_')
   apply (simp add: catch_def)
   apply (rule ccorres_symb_exec_r) 
     apply (rule ccorres_split_nothrow_novcg_case_sum)
           apply (ctac (no_vcg) add: sendFaultIPC_ccorres)
          apply ceqv
         apply clarsimp
         apply (rule ccorres_cond_empty)
         apply (rule ccorres_return_Skip')
        apply clarsimp
        apply (rule ccorres_cond_univ)
        apply (ctac (no_vcg) add: handleDoubleFault_ccorres [unfolded dc_def])
       apply (simp add: sendFaultIPC_def)
       apply wp
         apply ((wp hoare_vcg_all_lift_R hoare_drop_impE_R |wpc |simp add: throw_def)+)[1]
        apply clarsimp
        apply ((wp hoare_vcg_all_lift_R hoare_drop_impE_R |wpc |simp add: throw_def)+)[1]
       apply (wp)
      apply (simp add: guard_is_UNIV_def)
     apply (simp add: guard_is_UNIV_def)
    apply clarsimp
    apply vcg
   apply clarsimp
   apply (rule conseqPre, vcg)
   apply clarsimp
  apply (clarsimp simp: st_tcb_at')
  done

lemma getMessageInfo_less_4:
  "\<lbrace>\<top>\<rbrace> getMessageInfo t \<lbrace>\<lambda>rv s. msgExtraCaps rv < 4\<rbrace>"
  apply (simp add: getMessageInfo_def)
  apply wp
  apply (rule hoare_strengthen_post, rule hoare_vcg_prop)
  apply (simp add: messageInfoFromWord_def Let_def
                   Types_H.msgExtraCapBits_def)
  apply (rule minus_one_helper5, simp)
  apply simp
  apply (rule word_and_le1)
  done

lemma invs_queues_imp:
  "invs' s \<longrightarrow> valid_queues s"
  by clarsimp

(* FIXME: move *)
lemma msgLength_CL_from_H [simp]:
  "msgLength_CL (mi_from_H mi) = msgLength mi"
  by (simp add: mi_from_H_def)

lemma getMRs_length:
  "\<lbrace>\<lambda>s. msgLength mi \<le> 120\<rbrace> getMRs thread buffer mi
  \<lbrace>\<lambda>args s. if buffer = None then length args = min (unat n_msgRegisters) (unat (msgLength mi))
            else length args = unat (msgLength mi)\<rbrace>"
  apply (cases buffer)
   apply (simp add: getMRs_def)
   apply (rule hoare_pre, wp)
    apply (rule asUser_const_rv)
    apply simp
    apply (wp mapM_length)
   apply (simp add: min_def length_msgRegisters)
  apply (clarsimp simp: n_msgRegisters_def)
  apply (simp add: getMRs_def)
  apply (rule hoare_pre, wp)
    apply simp
    apply (wp mapM_length asUser_const_rv mapM_length)
  apply (clarsimp simp: length_msgRegisters)
  apply (simp add: min_def split: if_splits)
  apply (clarsimp simp: word_le_nat_alt)
  apply (simp add: msgMaxLength_def msgLengthBits_def n_msgRegisters_def)
  done

lemma getMessageInfo_msgLength':
  "\<lbrace>\<top>\<rbrace> getMessageInfo t \<lbrace>\<lambda>rv s. msgLength rv \<le> 0x78\<rbrace>"
  apply (simp add: getMessageInfo_def)
  apply wp
  apply (rule hoare_strengthen_post, rule hoare_vcg_prop)
  apply (simp add: messageInfoFromWord_def Let_def msgMaxLength_def not_less
                   Types_H.msgExtraCapBits_def split: split_if )
  done

lemma handleInvocation_ccorres:
  "ccorres (K dc \<currency> dc) (liftxf errstate id (K ()) ret__unsigned_long_')
       (invs' and (\<lambda>s. vs_valid_duplicates' (ksPSpace s)) and
        ct_active' and sch_act_simple and
        (\<lambda>s. \<forall>x. ksCurThread s \<notin> set (ksReadyQueues s x)))
       (UNIV \<inter> {s. isCall_' s = from_bool isCall}
             \<inter> {s. isBlocking_' s = from_bool isBlocking}) []
       (handleInvocation isCall isBlocking) (Call handleInvocation_'proc)"
  apply (cinit' lift: isCall_' isBlocking_'
                simp: whileAnno_def handleInvocation_def2)
   apply (simp add: liftE_bindE del: Collect_const cong: call_ignore_cong)
   apply (ctac(no_vcg) add: getCurThread_ccorres)
     apply (ctac(no_vcg) add: getMessageInfo_ccorres)
      apply (simp del: Collect_const cong: call_ignore_cong)
      apply csymbr
      apply (ctac(no_vcg) add: getRegister_ccorres)
       apply (simp add: Syscall_H.syscall_def
                        liftE_bindE split_def bindE_bind_linearise
                  cong: call_ignore_cong
                   del: Collect_const)
       apply (rule_tac ccorres_split_nothrow_case_sum)
            apply (ctac add: capFaultOnFailure_ccorres
                                 [OF lookupCapAndSlot_ccorres])
           apply ceqv
          apply (simp add: ccorres_cond_iffs Collect_False
                     cong: call_ignore_cong
                      del: Collect_const)
          apply (simp only: bind_assoc) 
          apply (ctac(no_vcg) add: lookupIPCBuffer_ccorres)
           apply (simp add: liftME_def bindE_assoc del: Collect_const)
           apply (simp add: bindE_bind_linearise del: Collect_const)
           apply (rule_tac xf'="\<lambda>s. (status_' s,
                                current_extra_caps_' (globals s))"
                             and ef'=fst and vf'=snd and es=errstate
                        in ccorres_split_nothrow_novcg_case_sum)
                 apply (rule ccorres_call, rule lookupExtraCaps_ccorres, simp+)
                apply (rule ceqv_tuple2, ceqv, ceqv)
               apply (simp add: returnOk_bind liftE_bindE
                                Collect_False
                                ccorres_cond_iffs ts_Restart_case_helper'
                           del: Collect_const cong: bind_cong)
               apply (rule ccorres_rhs_assoc2,
                      rule_tac xf'="length___unsigned_long_'"
                            and r'="\<lambda>rv rv'. unat rv' = length rv"
                            in ccorres_split_nothrow)
                   apply (rule ccorres_add_return2)
                   apply (rule ccorres_symb_exec_l)
                      apply (rule_tac P="\<lambda>s. rvd \<noteq> Some 0 \<and> (if rvd = None then
                                               length x = min (unat (n_msgRegisters))
                                                            (unat (msgLength (messageInfoFromWord ret__unsigned_long)))
                                             else 
                                               length x = (unat (msgLength (messageInfoFromWord ret__unsigned_long))))" 
                                  and P'=UNIV
                                   in ccorres_from_vcg)
                      apply (clarsimp simp: return_def)
                      apply (rule conseqPre, vcg)
                      apply (clarsimp simp: word_less_nat_alt)
                      apply (rule conjI)
                       apply clarsimp
                       apply (case_tac rvd, clarsimp simp: option_to_0_def min_def n_msgRegisters_def)
                       apply (clarsimp simp: option_to_0_def)
                      apply clarsimp
                      apply (case_tac rvd, clarsimp simp: option_to_0_def min_def  n_msgRegisters_def split: if_splits)
                      apply (clarsimp simp: option_to_0_def)
                     apply wp
                    apply (wp getMRs_length)
                   apply simp
                  apply ceqv
                 apply csymbr
                 apply (simp only: bind_assoc[symmetric])
                 apply (rule ccorres_split_nothrow_novcg_case_sum)
                       apply (ctac add: decodeInvocation_ccorres)
                      apply ceqv
                     apply (simp add: Collect_False exception_defs
                                      replyOnRestart_def liftE_def bind_assoc
                                 del: Collect_const)
                     apply (rule ccorres_move_c_guard_tcb)
                     apply (rule getThreadState_ccorres_foo)
                     apply csymbr
                     apply (rule ccorres_abstract_cleanup)
                     apply (rule_tac P="ret__unsigned_long = thread_state_to_tsType rvg"
                                 in ccorres_gen_asm2)
                     apply (simp add: thread_state_to_tsType_eq_Restart from_bool_0
                                 del: Collect_const add: Collect_const[symmetric])
                     apply (rule ccorres_Cond_rhs_Seq)
                      apply (rule ccorres_rhs_assoc)+
                      apply (rule ccorres_Cond_rhs_Seq)
                       apply (simp add: bind_assoc)
                       apply (ctac(no_vcg) add: replyFromKernel_success_empty_ccorres)
                        apply (ctac(no_vcg) add: setThreadState_ccorres)
                         apply (rule ccorres_return_CE[folded return_returnOk], simp+)[1]
                        apply (wp)
                       apply (rule hoare_strengthen_post, rule rfk_invs')
                       apply auto[1]
                      apply simp
                      apply (ctac(no_vcg) add: setThreadState_ccorres)
                       apply (rule ccorres_return_CE[folded return_returnOk], simp+)[1]
                      apply wp
                     apply simp
                     apply (rule ccorres_return_CE[folded return_returnOk], simp+)[1]
                    apply wpc
                     apply (simp add: syscall_error_rel_def from_bool_0 exception_defs
                                      Collect_False ccorres_cond_iffs Collect_True
                                 del: Collect_const)
                     apply (rule ccorres_rhs_assoc)+
                     apply (simp add: liftE_def Collect_const[symmetric]
                                 del: Collect_const)
                     apply (rule ccorres_Cond_rhs_Seq)
                      apply simp
                      apply (ctac(no_vcg) add: replyFromKernel_error_ccorres)
                       apply (rule ccorres_split_throws)
                        apply (rule ccorres_return_CE[folded return_returnOk], simp+)[1]
                       apply vcg
                      apply wp
                     apply simp
                     apply (rule ccorres_split_throws)
                      apply (rule ccorres_return_CE[folded return_returnOk], simp+)[1]
                     apply vcg
                    apply (simp add: cintr_def)
                    apply (rule ccorres_split_throws)
                     apply (rule ccorres_return_C_errorE, simp+)[1]
                    apply vcg
                   apply (simp add: invocationCatch_def o_def)
                   apply (rule_tac Q="\<lambda>rv'. invs' and tcb_at' rv"
                               and E="\<lambda>ft. invs' and tcb_at' rv"
                              in hoare_post_impErr)
                     apply (wp hoare_split_bind_case_sumE
                               alternative_wp hoare_drop_imps
                               setThreadState_nonqueued_state_update
                               ct_in_state'_set setThreadState_st_tcb
                               hoare_vcg_all_lift sts_ksQ'
                                 | wpc | wps)+
                    apply auto[1]
                   apply clarsimp
                  apply (clarsimp simp: guard_is_UNIV_def Collect_const_mem)
                  apply (simp add: "StrictC'_thread_state_defs" mask_def)
                  apply (simp add: typ_heap_simps)
                  apply (case_tac ts, simp_all add: cthread_state_relation_def)[1]
                 apply (clarsimp simp: guard_is_UNIV_def Collect_const_mem)
                 apply (clarsimp simp add: intr_and_se_rel_def exception_defs
                                           syscall_error_rel_def cintr_def
                                    split: sum.split_asm)
                apply (simp add: conj_ac)
                apply (wp getMRs_sysargs_rel)
               apply (simp add: )
               apply vcg
              apply (simp add: ccorres_cond_iffs ccorres_seq_cond_raise
                               Collect_True Collect_False
                          del: Collect_const)
              apply (rule ccorres_rhs_assoc)+
              apply (simp add: ccorres_cond_iffs Collect_const[symmetric]
                          del: Collect_const)
              apply (rule ccorres_Cond_rhs_Seq)
               apply (simp add: from_bool_0 liftE_def)
               apply (ctac(no_vcg) add: handleFault_ccorres)
                apply (rule ccorres_split_throws)
                 apply (rule ccorres_return_CE[folded return_returnOk], simp+)[1]
                apply vcg
               apply wp
              apply (simp add: from_bool_0 liftE_def)
              apply (rule ccorres_split_throws)
               apply (rule ccorres_return_CE[folded return_returnOk], simp+)[1]
              apply vcg
             apply (simp add: ball_conj_distrib)
             apply (wp lookupExtraCaps_excaps_in_mem
                       lec_dimished'[unfolded o_def]
                       lec_derived'[unfolded o_def])
            apply (clarsimp simp: guard_is_UNIV_def option_to_ptr_def
                                  mi_from_H_def)
           apply (clarsimp simp: guard_is_UNIV_def)
          apply simp
          apply (wp lookupIPCBuffer_Some_0)
         apply (simp add: Collect_True liftE_def return_returnOk
                     del: Collect_const)
         apply (rule ccorres_rhs_assoc)+
         apply (simp del: Collect_const)
         apply (rule_tac P=\<top> in ccorres_cross_over_guard)
         apply (rule ccorres_symb_exec_r)
           apply (rule ccorres_split_nothrow_novcg_dc)
              apply (rule ccorres_when[where R=\<top>])
               apply (simp add: from_bool_0 Collect_const_mem)
              apply (ctac add: handleFault_ccorres)
             apply (rule ccorres_split_throws)
              apply (rule ccorres_return_CE, simp+)[1]
             apply vcg
            apply wp
           apply (simp add: guard_is_UNIV_def)
          apply vcg
         apply (rule conseqPre, vcg)
         apply clarsimp 
        apply (simp, wp lcs_diminished'[unfolded o_def])
       apply clarsimp 
       apply (vcg exspec= lookupCapAndSlot_modifies)
      apply simp
      apply (wp getMessageInfo_less_4 getMessageInfo_le3 getMessageInfo_msgLength')
     apply (simp add: msgMaxLength_def, wp getMessageInfo_msgLength')[1]
    apply simp
    apply wp
   apply (clarsimp simp: Collect_const_mem)
   apply (simp add: Kernel_C.msgInfoRegister_def State_H.msgInfoRegister_def
                    ARMMachineTypes.msgInfoRegister_def Kernel_C.R1_def
                    Kernel_C.capRegister_def State_H.capRegister_def
                    ARMMachineTypes.capRegister_def Kernel_C.R0_def)
   apply (clarsimp simp: cfault_rel_def option_to_ptr_def)
   apply (simp add: fault_cap_fault_lift is_cap_fault_def)
   apply (frule lookup_failure_rel_fault_lift, assumption)
   apply clarsimp
  apply (clarsimp simp: ct_in_state'_def st_tcb_at_tcb_at')
  apply (auto simp: ct_in_state'_def sch_act_simple_def intro!: active_ex_cap' 
              elim!: st_tcb'_weakenE dest!: st_tcb_at_idle_thread')[1]
  done

lemma ccorres_return_void_catchbrk:
  "ccorres_underlying sr G r xf ar axf P P' hs
     f return_void_C
  \<Longrightarrow> ccorres_underlying sr G r xf ar axf P P' (catchbrk_C # hs)
     f return_void_C"
  apply (simp add: return_void_C_def catchbrk_C_def)
  apply (rule ccorresI')
  apply clarsimp
  apply (erule exec_handlers_Seq_cases')
   prefer 2
   apply (clarsimp elim!: exec_Normal_elim_cases)
  apply (clarsimp elim!: exec_Normal_elim_cases)
  apply (erule exec_handlers.cases, simp_all)
   prefer 2
   apply (auto elim!: exec_Normal_elim_cases)[1]
  apply (clarsimp elim!: exec_Normal_elim_cases)
  apply (erule exec_Normal_elim_cases, simp_all)
  apply (clarsimp elim!: exec_Normal_elim_cases)
  apply (erule(4) ccorresE)
   apply (rule EHAbrupt)
    apply (fastforce intro: exec.intros)
   apply assumption
  apply clarsimp
  apply (frule exec_handlers_less)
   apply clarsimp
  apply fastforce
  done

lemma handleReply_ccorres:
  "ccorres dc xfdc   
       (\<lambda>s. invs' s \<and> st_tcb_at' (\<lambda>a. \<not> isReply a) (ksCurThread s) s \<and> sch_act_simple s)
       UNIV
       []
       (handleReply) 
       (Call handleReply_'proc)"
  apply cinit
   apply (rule ccorres_pre_getCurThread)

   apply (simp only: getThreadCallerSlot_def locateSlot_conv)


   apply (rule_tac P="\<lambda>s. thread=ksCurThread s \<and> invs' s \<and> is_aligned thread 9" 
                   and r'="\<lambda> a c. c = cte_Ptr a" 
                   and xf'="callerSlot_'" and P'=UNIV in ccorres_split_nothrow)
       apply (rule ccorres_from_vcg)
       apply (rule allI, rule conseqPre, vcg)
       apply (clarsimp simp: return_def word_sle_def)
       apply (frule aligned_neg_mask) 
       apply (simp add: mask_def tcbCallerSlot_def Kernel_C.tcbCaller_def  
              cte_level_bits_def size_of_def)
       apply (simp add: rf_sr_ksCurThread) 
       apply (subst ptr_val_tcb_ptr_mask')
        apply (rule tcb_at_invs', simp) 
       apply simp

      apply ceqv

     apply (simp del: Collect_const)
     apply (rule ccorres_getSlotCap_cte_at)
     apply (rule ccorres_move_c_guard_cte)
     apply ctac
       apply (wpc, simp_all)
                 apply (rule ccorres_fail)
                apply (simp add: ccap_relation_NullCap_iff cap_tag_defs)
                apply (rule ccorres_split_throws)
                 apply (rule ccorres_Catch)
                 apply csymbr
                 apply (rule ccorres_cond_false)
                 apply (rule ccorres_cond_true)
                 apply simp
                 apply (rule ccorres_return_void_catchbrk)
                 apply (rule ccorres_return_void_C[unfolded dc_def])
                apply (vcg exspec=doReplyTransfer_modifies)
               apply (rule ccorres_fail)+
          apply (wpc, simp_all)
           apply (rule ccorres_fail)
          apply (rule ccorres_split_throws)
           apply (rule ccorres_Catch)
           apply csymbr
           apply (rule ccorres_cond_true)
           apply (frule cap_get_tag_isCap_unfolded_H_cap(8))
           apply simp
           apply (rule ccorres_rhs_assoc)+
           apply csymbr+
           apply (frule cap_get_tag_ReplyCap)
           apply (clarsimp simp: to_bool_def)
           apply csymbr+
           apply simp
           apply (rule ccorres_assert2)
           apply (fold dc_def)
           apply (rule ccorres_add_return2)
           apply (ctac (no_vcg))
            apply (rule ccorres_return_void_catchbrk)
            apply (rule ccorres_return_void_C)
           apply wp
          apply (vcg exspec=doReplyTransfer_modifies)

         apply (rule ccorres_fail)+

      apply simp_all

      apply (simp add: getSlotCap_def)
      apply (wp getCTE_wp')[1]

     apply vcg

    apply wp

   apply vcg

  apply clarsimp
  apply (intro allI conjI impI,
        simp_all add: cap_get_tag_isCap_unfolded_H_cap cap_tag_defs)
     apply (rule tcb_aligned', rule tcb_at_invs', simp)
    apply (auto simp: cte_wp_at_ctes_of valid_cap'_def
                   dest!: ctes_of_valid')[1]
   apply clarsimp
   apply (frule cap_get_tag_isCap_unfolded_H_cap)
   apply (simp add: cap_get_tag_ReplyCap)
  apply clarsimp
  apply (frule cap_get_tag_isCap_unfolded_H_cap)
  apply (simp add: cap_get_tag_ReplyCap to_bool_def)
  done

lemma deleteCallerCap_ccorres [corres]:
  "ccorres dc xfdc   
       (\<lambda>s. invs' s \<and> is_aligned receiver 9)
       (UNIV \<inter> {s. receiver_' s = tcb_ptr_to_ctcb_ptr receiver})
       []
       (deleteCallerCap receiver) 
       (Call deleteCallerCap_'proc)"
  apply (cinit lift: receiver_')
   apply (simp only: getThreadCallerSlot_def locateSlot_conv)
   apply (rule_tac P="\<lambda>_. is_aligned receiver 9" and r'="\<lambda> a c. cte_Ptr a = c" 
                   and xf'="callerSlot_'" and P'=UNIV in ccorres_split_nothrow_novcg)
       apply (rule ccorres_from_vcg)
       apply (rule allI, rule conseqPre, vcg)
       apply (clarsimp simp: return_def word_sle_def)
       apply (frule aligned_neg_mask) 
       apply (simp add: mask_def tcbCallerSlot_def Kernel_C.tcbCaller_def  
              cte_level_bits_def size_of_def)
       apply (drule ptr_val_tcb_ptr_mask2)
       apply (simp add: mask_def)
      apply ceqv
     apply (ctac add:  cteDeleteOne_stronger_ccorres)
    apply wp
   apply clarsimp
   apply (simp add: guard_is_UNIV_def)
  apply clarsimp
  done


(* FIXME: MOVE *)
lemma cap_case_EndpointCap_AsyncEndpointCap:
  "(case cap of EndpointCap v0 v1 v2 v3 v4 \<Rightarrow> f v0 v1 v2 v3 v4 
              | AsyncEndpointCap v0 v1 v2 v3  \<Rightarrow> g v0 v1 v2 v3
              | _ \<Rightarrow> h)
   = (if isEndpointCap cap
      then f (capEPPtr cap)  (capEPBadge cap) (capEPCanSend cap) (capEPCanReceive cap) (capEPCanGrant cap) 
      else if isAsyncEndpointCap cap
           then g (capAEPPtr cap)  (capAEPBadge cap) (capAEPCanSend cap) (capAEPCanReceive cap)
           else h)"
  by (simp add: isCap_simps
         split: capability.split)


(* FIXME: MOVE *)
lemma capFaultOnFailure_if_case_sum:
  " (capFaultOnFailure epCPtr b (if c then f else g) >>=
      sum.case_sum (handleFault thread) return) =
    (if c then ((capFaultOnFailure epCPtr b  f) 
                 >>= sum.case_sum (handleFault thread) return)
          else ((capFaultOnFailure epCPtr b  g) 
                 >>= sum.case_sum (handleFault thread) return))"
  by (case_tac c, clarsimp, clarsimp)



(* FIXME:  MOVE to Corres_C.thy *)
lemma ccorres_trim_redundant_throw_break:
  "\<lbrakk>ccorres_underlying rf_sr \<Gamma> arrel axf arrel axf G G' (SKIP # hs) a c;
          \<And>s f. axf (global_exn_var_'_update f s) = axf s \<rbrakk>
  \<Longrightarrow> ccorres_underlying rf_sr \<Gamma> r xf arrel axf G G' (SKIP # hs)
          a (c;; Basic (global_exn_var_'_update (\<lambda>_. Break));; THROW)"
  apply -
  apply (rule ccorres_trim_redundant_throw')
    apply simp
   apply simp
  apply simp
  done

lemma invs_valid_objs_strengthen:
  "invs' s \<longrightarrow> valid_objs' s" by fastforce

lemma ct_not_ksQ_strengthen:
  "thread = ksCurThread s \<and> ksCurThread s \<notin> set (ksReadyQueues s p) \<longrightarrow> thread \<notin> set (ksReadyQueues s p)" by fastforce

lemma handleWait_ccorres:
  "ccorres dc xfdc   
       (\<lambda>s. invs' s \<and> st_tcb_at' simple' (ksCurThread s) s
               \<and> sch_act_sane s \<and> (\<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p)))
       UNIV
       []
       (handleWait) 
       (Call handleWait_'proc)"
  apply cinit
   apply (rule ccorres_pre_getCurThread)
   apply (ctac)
     apply (ctac)
       apply (simp add: catch_def)
       apply (simp add: capFault_bindE)
       apply (simp add: bindE_bind_linearise)

       apply (rule_tac xf'=lu_ret___struct_lookupCap_ret_C_'
                 in ccorres_split_nothrow_case_sum) 
            apply (rule  capFaultOnFailure_ccorres)
            apply (ctac add: lookupCap_ccorres)
           apply ceqv

          apply clarsimp
          apply (rule ccorres_Catch)
          apply csymbr
          apply (simp add: cap_get_tag_isCap del: Collect_const) 
          apply (clarsimp simp: cap_case_EndpointCap_AsyncEndpointCap capFaultOnFailure_if_case_sum)
          apply (rule ccorres_cond_both' [where Q=\<top> and Q'=\<top>])
            apply clarsimp

           apply (rule ccorres_rhs_assoc)+ 
           apply csymbr
           apply (simp add: case_bool_If capFaultOnFailure_if_case_sum)

           apply (rule ccorres_if_cond_throws_break2 [where Q=\<top> and Q'=\<top>])
              apply clarsimp

              apply (simp add: cap_get_tag_isCap[symmetric] cap_get_tag_EndpointCap
                del: Collect_const)
              apply (simp add: to_bool_def)


             apply (rule ccorres_rhs_assoc)+

             apply (simp add: capFaultOnFailure_def rethrowFailure_def
                              handleE'_def throwError_def)
             apply (rule ccorres_cross_over_guard[where P=\<top>])
             apply (rule ccorres_symb_exec_r)
               apply (rule ccorres_cross_over_guard[where P=\<top>])
               apply (rule ccorres_symb_exec_r)
                 apply (rule ccorres_add_return2)
                 apply (rule ccorres_split_nothrow_call[where xf'=xfdc and d'="\<lambda>_. break_C"
                                              and Q="\<lambda>_ _. True" and Q'="\<lambda>_ _. UNIV"])
                        apply (ctac add: handleFault_ccorres[unfolded dc_def])
                       apply simp+
                    apply ceqv
                   apply (rule ccorres_break_return)
                    apply simp+
                  apply wp
                 apply (vcg exspec=handleFault_modifies)

                apply vcg
               apply (rule conseqPre, vcg)
               apply clarsimp

              apply vcg
             apply (rule conseqPre, vcg)
             apply clarsimp

            apply (simp add: liftE_bind) 
            apply (ctac add: receiveIPC_ccorres[unfolded dc_def])

           apply clarsimp
           apply (vcg exspec=handleFault_modifies)

          apply (clarsimp simp: capFaultOnFailure_if_case_sum case_bool_If)
          apply (rule ccorres_cond_both' [where Q=\<top> and Q'=\<top>])
            apply clarsimp

           apply (rule ccorres_rhs_assoc)+ 
           apply csymbr
           apply (simp add: case_bool_If capFaultOnFailure_if_case_sum)

           apply (rule ccorres_if_cond_throws_break2 [where Q=\<top> and Q'=\<top>])
              apply clarsimp

              apply (simp add: cap_get_tag_isCap[symmetric] cap_get_tag_AsyncEndpointCap
                del: Collect_const)
              apply (simp add: to_bool_def)


             apply (rule ccorres_rhs_assoc)+

             apply (simp add: capFaultOnFailure_def rethrowFailure_def
                              handleE'_def throwError_def)
             apply (rule ccorres_cross_over_guard[where P=\<top>])
             apply (rule ccorres_symb_exec_r)
               apply (rule ccorres_cross_over_guard[where P=\<top>])
               apply (rule ccorres_symb_exec_r)
                 apply (rule ccorres_add_return2)
                 apply (rule ccorres_split_nothrow_call[where xf'=xfdc and d'="\<lambda>_. break_C"
                                              and Q="\<lambda>_ _. True" and Q'="\<lambda>_ _. UNIV"])
                        apply (ctac add: handleFault_ccorres[unfolded dc_def])
                       apply simp+
                    apply ceqv
                   apply (rule ccorres_break_return)
                    apply simp+
                  apply wp
                 apply (vcg exspec=handleFault_modifies)

                apply vcg
               apply (rule conseqPre, vcg)
               apply clarsimp

              apply vcg
             apply (rule conseqPre, vcg)
             apply clarsimp

            apply (simp add: liftE_bind) 
            apply (ctac  add: receiveAsyncIPC_ccorres[unfolded dc_def])

           apply clarsimp
           apply (vcg exspec=handleFault_modifies)

          apply (rule ccorres_cond_univ)
          apply (simp add: capFaultOnFailure_def rethrowFailure_def
                           handleE'_def throwError_def)
          
          apply (rule ccorres_rhs_assoc)+
          apply (rule ccorres_cross_over_guard[where P=\<top>])
          apply (rule ccorres_symb_exec_r)
            apply (rule ccorres_cross_over_guard[where P=\<top>])
            apply (rule ccorres_symb_exec_r)
              apply (ctac add: handleFault_ccorres[unfolded dc_def])
             apply vcg
            apply (rule conseqPre, vcg)
            apply clarsimp

           apply vcg
          apply (rule conseqPre, vcg)
          apply clarsimp

         apply clarsimp
         apply (rule ccorres_add_return2)
         apply (rule ccorres_rhs_assoc)+
         apply (rule ccorres_cross_over_guard[where P=\<top>])
         apply (rule ccorres_symb_exec_r)
           apply (ctac add: handleFault_ccorres[unfolded dc_def])
             apply (rule ccorres_split_throws)
              apply (rule ccorres_return_void_C [unfolded dc_def])        
             apply vcg

            apply wp
           apply (vcg exspec=handleFault_modifies)
          apply vcg
         apply (rule conseqPre, vcg)
         apply clarsimp
        apply (wp) apply clarsimp 
        apply (wp hoare_drop_imps)

       apply clarsimp
       apply (vcg exspec=isBlocked_modifies exspec=lookupCap_modifies) 

      apply wp
     apply vcg
    apply clarsimp
    apply (strengthen ct_not_ksQ_strengthen invs_valid_objs_strengthen)
    apply (wp deleteCallerCap_ct_not_ksQ hoare_vcg_all_lift)

   apply (vcg exspec=deleteCallerCap_modifies)

  apply (clarsimp simp: sch_act_sane_def)
  apply (simp add: cap_get_tag_isCap[symmetric])

  apply (simp add: Kernel_C.capRegister_def State_H.capRegister_def ct_in_state'_def
                    ARMMachineTypes.capRegister_def Kernel_C.R0_def)
  apply (intro conjI impI allI)
        apply (rule_tac s=s in tcb_aligned')
        apply (clarsimp simp: cfault_rel_def fault_cap_fault_lift
                         lookup_fault_missing_capability_lift is_cap_fault_def)+
  apply (case_tac w, clarsimp+)
  done

lemma handleYield_ccorres:
  "ccorres dc xfdc   
       (invs' and ct_active')
       UNIV
       []
       (handleYield) 
       (Call handleYield_'proc)"
  apply cinit
   apply (rule ccorres_pre_getCurThread)    
   apply (ctac add: tcbSchedDequeue_ccorres)
     apply (ctac  add: tcbSchedAppend_ccorres)
       apply (ctac add: rescheduleRequired_ccorres)
      apply (wp weak_sch_act_wf_lift_linear tcbSchedAppend_valid_objs')
     apply (vcg exspec= tcbSchedAppend_modifies)
    apply (wp weak_sch_act_wf_lift_linear)
   apply (vcg exspec= tcbSchedDequeue_modifies)
  apply (clarsimp simp: tcb_at_invs' invs_valid_objs'
                        valid_objs'_maxPriority valid_objs'_maxDomain)
  apply (auto simp: obj_at'_def st_tcb_at'_def ct_in_state'_def valid_objs'_maxDomain)
  done


lemma getIRQState_sp:
  "\<lbrace>P\<rbrace> getIRQState irq \<lbrace>\<lambda>rv s. rv = intStateIRQTable (ksInterruptState s) irq \<and> P s\<rbrace>"
  apply (simp add: getIRQState_def getInterruptState_def)
  apply wp
  apply simp
  done
  
lemma ccorres_pre_getIRQState:
  assumes cc: "\<And>rv. ccorres r xf (P rv) (P' rv) hs (f rv) c"
  shows   "ccorres r xf 
                  (\<lambda>s. irq \<le> ucast maxIRQ \<and> P (intStateIRQTable (ksInterruptState s) irq) s)
                  {s. \<forall>rv. index (intStateIRQTable_' (globals s)) (unat irq) = irqstate_to_C rv \<longrightarrow> s \<in> P' rv }
                          hs (getIRQState irq >>= (\<lambda>rv. f rv)) c" 
  apply (rule ccorres_guard_imp)
    apply (rule ccorres_symb_exec_l)
       defer
       apply (simp add: getIRQState_def getInterruptState_def)
       apply wp
       apply simp
      apply (rule getIRQState_sp)
     apply (simp add: getIRQState_def getInterruptState_def)
    apply assumption
   prefer 2
   apply (rule ccorres_guard_imp)
     apply (rule cc)
    apply simp
   apply assumption
  apply clarsimp
  apply (erule allE)
  apply (erule impE)
   prefer 2
   apply assumption
  apply (clarsimp simp: rf_sr_def cstate_relation_def
                        Let_def cinterrupt_relation_def)
  done

(* FIXME: move *)  
lemma ccorres_aep_cases:
  assumes P: "\<And>p b send d. cap = AsyncEndpointCap p b send d \<Longrightarrow> ccorres r xf (P p b send d) (P' p b send d) hs (a cap) (c cap)"
  assumes Q: "\<not>isAsyncEndpointCap cap \<Longrightarrow> ccorres r xf (Q cap) (Q' cap) hs (a cap) (c cap)"
  shows
  "ccorres r xf (\<lambda>s. (\<forall>p b send d. cap = AsyncEndpointCap p b send d \<longrightarrow> P p b send d s) \<and> 
                     (\<not>isAsyncEndpointCap cap \<longrightarrow> Q cap s)) 
               ({s. \<forall>p b send d. cap = AsyncEndpointCap p b send d \<longrightarrow> s \<in> P' p b send d} \<inter> 
                {s. \<not>isAsyncEndpointCap cap \<longrightarrow> s \<in> Q' cap}) 
               hs (a cap) (c cap)"
  apply (cases "isAsyncEndpointCap cap")
   apply (simp add: isCap_simps)
   apply (elim exE)
   apply (rule ccorres_guard_imp)
     apply (erule P)
    apply simp
   apply simp
  apply (rule ccorres_guard_imp)
    apply (erule Q)
   apply clarsimp
  apply clarsimp
  done

(* FIXME: generalise the one in Interrupt_C *)
lemma getIRQSlot_ccorres2:
  "ccorres (op = \<circ> Ptr) slot_'
          \<top> UNIV hs
      (getIRQSlot irq) (\<acute>slot :== CTypesDefs.ptr_add \<acute>intStateIRQNode (uint (ucast irq :: word32)))"
  apply (rule ccorres_from_vcg[where P=\<top> and P'=UNIV])
  apply (rule allI, rule conseqPre, vcg)
  apply (clarsimp simp: getIRQSlot_def liftM_def getInterruptState_def
                        locateSlot_conv)
  apply (simp add: simpler_gets_def bind_def return_def)
  apply (clarsimp simp: rf_sr_def cstate_relation_def Let_def
                        cinterrupt_relation_def size_of_def
                        cte_level_bits_def mult.commute mult.left_commute ucast_nat_def)
  done

lemma getIRQSlot_ccorres3:
  "(\<And>rv. ccorresG rf_sr \<Gamma> r xf (P rv) (P' rv) hs (f rv) c) \<Longrightarrow>
   ccorresG rf_sr \<Gamma> r xf
     (\<lambda>s. P (intStateIRQNode (ksInterruptState s) + 2 ^ cte_level_bits * of_nat (unat irq)) s)
     {s. s \<in> P' (ptr_val (CTypesDefs.ptr_add (intStateIRQNode_' (globals s)) (uint (ucast irq :: word32))))} hs
     (getIRQSlot irq >>= f) c"
  apply (simp add: getIRQSlot_def locateSlot_conv liftM_def getInterruptState_def)
  apply (rule ccorres_symb_exec_l'[OF _ _ gets_sp])
    apply (rule ccorres_guard_imp2, assumption)
    apply (clarsimp simp: getIRQSlot_ccorres_stuff[where x=undefined]
                          objBits_simps cte_level_bits_def
                          ucast_nat_def uint_ucast uint_up_ucast is_up)
   apply wp
  done

lemma handleInterrupt_ccorres:
  "ccorres dc xfdc 
           (invs' and K (irq \<le> ucast maxIRQ))
           (UNIV \<inter> \<lbrace>\<acute>irq = ucast irq\<rbrace>)
           []
           (handleInterrupt irq) 
           (Call handleInterrupt_'proc)" 
  apply (cinit lift: irq_' cong: call_ignore_cong)
   apply (rule ccorres_pre_getIRQState)
   apply wpc
     apply simp
     apply (rule ccorres_fail)
    apply (simp add: bind_assoc cong: call_ignore_cong)
    apply (rule ccorres_move_const_guards)+
    apply (rule ccorres_cond_true_seq)
    apply (rule ccorres_rhs_assoc)+
    apply csymbr
    apply (rule getIRQSlot_ccorres3)
    apply (rule ccorres_getSlotCap_cte_at)
    apply (rule_tac P="cte_at' rva" in ccorres_cross_over_guard)
    apply (rule ccorres_Guard_Seq)+
    apply ctac
      apply csymbr
      apply csymbr
      apply (rule ccorres_aep_cases)
       apply (clarsimp cong: call_ignore_cong simp del: Collect_const)
       apply (rule_tac b=send in ccorres_case_bools)
        apply simp
        apply (rule ccorres_cond_true_seq)
        apply (rule ccorres_rhs_assoc)+
        apply csymbr
        apply csymbr
        apply (rule ccorres_cond_true_seq)
        apply (rule ccorres_rhs_assoc)+
        apply csymbr
        apply csymbr
        apply (ctac (no_vcg) add: sendAsyncIPC_ccorres)
         apply (ctac (no_vcg) add: maskInterrupt_ccorres)
          apply (ctac add: ackInterrupt_ccorres [unfolded dc_def])
         apply wp
       apply (simp del: Collect_const)
       apply (rule ccorres_cond_true_seq)
       apply (rule ccorres_rhs_assoc)+
       apply csymbr
       apply csymbr
       apply (rule ccorres_cond_false_seq)
       apply simp
       apply (ctac (no_vcg) add: maskInterrupt_ccorres)
        apply (ctac add: ackInterrupt_ccorres [unfolded dc_def])
       apply wp
      apply (rule_tac P=\<top> and P'="{s. ret__int_' s = 0 \<and> cap_get_tag cap \<noteq> scast cap_async_endpoint_cap}" in ccorres_inst)
      apply (clarsimp simp: isCap_simps simp del: Collect_const)
      apply (case_tac rvb, simp_all del: Collect_const)[1]
                prefer 3
                apply metis
               apply ((rule ccorres_guard_imp2,
                       rule ccorres_cond_false_seq, simp, 
                       rule ccorres_cond_false_seq, simp,
                       ctac (no_vcg) add: maskInterrupt_ccorres,
                       ctac (no_vcg) add: ackInterrupt_ccorres [unfolded dc_def],
                       wp, simp)+)
     apply simp
     apply (wp getSlotCap_wp)
    apply simp
    apply vcg
   apply (simp add: bind_assoc)
   apply (rule ccorres_move_const_guards)+
   apply (rule ccorres_cond_false_seq)
   apply (rule ccorres_cond_true_seq)
   apply (fold dc_def)[1]
   apply (rule ccorres_rhs_assoc)+
   apply (ctac (no_vcg) add: timerTick_ccorres)
    apply (ctac (no_vcg) add: resetTimer_ccorres)
     apply (ctac add: ackInterrupt_ccorres)
    apply wp
  apply (rule conjI)
   apply (clarsimp simp: cte_wp_at_ctes_of)
   apply (auto simp: word_less_alt word_le_def maxIRQ_def uint_up_ucast is_up_def 
                         source_size_def target_size_def word_size
                  intro: word_0_sle_from_less sless_positive)[1]
  apply (simp add: if_1_0_0 Collect_const_mem)
  apply (clarsimp simp: Kernel_C.IRQTimer_def Kernel_C.IRQNotifyAEP_def
                        cte_wp_at_ctes_of)
  apply (erule(1) cmap_relationE1[OF cmap_relation_cte])
  apply (clarsimp simp: typ_heap_simps')
  apply (simp add: cap_get_tag_isCap)
  apply (clarsimp simp: isCap_simps)
  apply (frule cap_get_tag_isCap_unfolded_H_cap)
  apply (frule cap_get_tag_to_H, assumption)
  apply (clarsimp simp: to_bool_def)
  apply (clarsimp simp: unat_word_ariths word_size word_less_nat_alt
                        signed_shift_guard_simpler_32 maxIRQ_def
                        word_sless_alt word_sle_def)
  done

end
end

