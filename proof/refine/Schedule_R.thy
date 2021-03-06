(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

theory Schedule_R
imports VSpace_R
begin

lemma gsa_wf [wp]: "\<lbrace>invs'\<rbrace> getSchedulerAction \<lbrace>sch_act_wf\<rbrace>"
  by (simp add: getSchedulerAction_def invs'_def valid_state'_def | wp)+

lemma gts_inv': "\<lbrace>P\<rbrace> getThreadState t \<lbrace>\<lambda>rv. P\<rbrace>"
  by (unfold getThreadState_def, wp)

lemma corres_if2:
 "\<lbrakk> G = G'; G \<Longrightarrow> corres r P P' a c; \<not> G' \<Longrightarrow> corres r Q Q' b d \<rbrakk>
    \<Longrightarrow> corres r (if G then P else Q) (if G' then P' else Q') (if G then a else b) (if G' then c else d)"
  by simp

lemma findM_awesome':
  assumes x: "\<And>x xs. suffixeq (x # xs) xs' \<Longrightarrow>
                  corres (\<lambda>a b. if b then (\<exists>a'. a = Some a' \<and> r a' (Some x)) else a = None)
                      P (P' (x # xs))
                      ((f >>= (\<lambda>x. return (Some x))) OR (return None)) (g x)"
  assumes y: "corres r P (P' []) f (return None)"
  assumes z: "\<And>x xs. suffixeq (x # xs) xs' \<Longrightarrow>
                 \<lbrace>P' (x # xs)\<rbrace> g x \<lbrace>\<lambda>rv s. \<not> rv \<longrightarrow> P' xs s\<rbrace>"
  assumes p: "suffixeq xs xs'"
  shows      "corres r P (P' xs) f (findM g xs)"
proof -
  have P: "f = do x \<leftarrow> (do x \<leftarrow> f; return (Some x) od) OR return None; if x \<noteq> None then return (the x) else f od"
    apply (rule ext)
    apply (auto simp add: bind_def alternative_def return_def split_def Pair_fst_snd_eq)
    done
  have Q: "\<lbrace>P\<rbrace> (do x \<leftarrow> f; return (Some x) od) OR return None \<lbrace>\<lambda>rv. if rv \<noteq> None then \<top> else P\<rbrace>"
    by (wp alternative_wp | simp)+
  show ?thesis using p
    apply (induct xs)
     apply (simp add: y del: dc_simp)
    apply (simp only: findM.simps)
    apply (subst P)
    apply (rule corres_guard_imp)
      apply (rule corres_split [OF _ x])
         apply (rule corres_if2)
           apply (case_tac ra, clarsimp+)[1]
          apply (rule corres_trivial, clarsimp)
          apply (case_tac ra, simp_all)[1]
         apply (erule(1) meta_mp [OF _ suffixeq_ConsD])
        apply assumption
       apply (rule Q)
      apply (rule hoare_post_imp [OF _ z])
      apply simp+
    done
qed

lemmas findM_awesome = findM_awesome' [OF _ _ _ suffixeq_refl]

lemma corres_rhs_disj_division:
  "\<lbrakk> P \<or> Q; P \<Longrightarrow> corres r R S x y; Q \<Longrightarrow> corres r T U x y \<rbrakk>
     \<Longrightarrow> corres r (R and T) (\<lambda>s. (P \<longrightarrow> S s) \<and> (Q \<longrightarrow> U s)) x y"
  apply (rule corres_guard_imp)
    apply (erule corres_disj_division)
     apply simp+
  done

lemma findM_alternative_awesome:
  assumes x: "\<And>x. corres (\<lambda>a b. if b then (\<exists>a'. a = Some a') else a = None)
                      P (P' and (\<lambda>s. x \<in> fn s)) ((f >>= (\<lambda>x. return (Some x))) OR (return None)) (g x)"
  assumes z: "\<And>x xs. \<lbrace>\<lambda>s. P' s \<and> x \<in> fn s \<and> set xs \<subseteq> fn s\<rbrace> g x \<lbrace>\<lambda>rv s. \<not> rv \<longrightarrow> P' s \<and> set xs \<subseteq> fn s\<rbrace>"
  assumes on_none: "corres dc P P' f g'"
  shows      "corres dc P (P' and (\<lambda>s. set xs \<subseteq> fn s)) f (findM g xs >>= (\<lambda>x. when (x = None) g'))"
proof -
  have P: "f = do x \<leftarrow> (do x \<leftarrow> f; return (Some x) od) OR return None; if x \<noteq> None then return (the x) else f od"
    apply (rule ext)
    apply (auto simp add: bind_def alternative_def return_def split_def Pair_fst_snd_eq)
    done
  have Q: "\<lbrace>P\<rbrace> (do x \<leftarrow> f; return (Some x) od) OR return None \<lbrace>\<lambda>rv. if rv \<noteq> None then \<top> else P\<rbrace>"
    by (wp alternative_wp | simp)+
  have R: "\<And>P x g xs. (do x \<leftarrow> if P then return (Some x) else findM g xs;
                         when (x = None) g'
                       od) = (if P then return () else (findM g xs >>= (\<lambda>x . when (x = None) g')))"
    by (simp add: when_def)
  show ?thesis
    apply (induct xs)
     apply (simp add: when_def)
     apply (fold dc_def, rule on_none)
    apply (simp only: findM.simps bind_assoc)
    apply (subst P)
    apply (rule corres_guard_imp)
      apply (rule corres_split [OF _ x])
        apply (subst R)
        apply (rule corres_if2)
          apply (case_tac xa, simp_all)[1]
         apply (rule corres_trivial, simp)
        apply assumption
       apply (rule Q)
      apply (rule hoare_post_imp [OF _ z])
      apply simp+
    done
qed

lemma awesome_case1:
  assumes x: "corres op = P P' (return False) (g x)"
  shows      "corres (\<lambda>a b. if b then (\<exists>a'. a = Some a' \<and> r a' (Some x)) else a = None)
            P P' ((f >>= (\<lambda>x. return (Some x))) OR (return None)) (g x)"
proof -
  have P: "return None = liftM (\<lambda>x. None) (return False)"
    by (simp add: liftM_def)
  show ?thesis
    apply (rule corres_alternate2)
    apply (subst P, simp only: corres_liftM_simp, simp)
    apply (subst corres_cong [OF refl refl refl refl])
     defer
     apply (rule x)
    apply (simp add: return_def)
    done
qed

lemma awesome_case2:
  assumes x: "corres (\<lambda>a b. r a (Some x) \<and> b) P P' f (g x)"
  shows      "corres (\<lambda>a b. if b then (\<exists>a'. a = Some a' \<and> r a' (Some x)) else a = None)
            P P' ((f >>= (\<lambda>x. return (Some x))) OR (return None)) (g x)"
  apply (rule corres_alternate1)
  apply (fold liftM_def)
  apply (simp add: o_def)
  apply (rule corres_rel_imp [OF x])
  apply simp
  done

lemma bind_select_corres:
  assumes x: "corres (\<lambda>rvs rv'. \<exists>rv\<in>rvs. r rv rv') P P' m m'"
  shows      "corres r P P' (m >>= select) m'"
  apply (insert x)
  apply (clarsimp simp: corres_underlying_def bind_def select_def split_def)
  done

lemma bind_select_fail_corres:
  assumes x: "corres (\<lambda>rvs rv'. \<exists>rv\<in>rvs. r rv rv') P P' m m'"
  shows      "corres r P P' (m >>= (\<lambda>x. select x \<sqinter> fail)) m'"
  apply (insert x)
  apply (clarsimp simp: corres_underlying_def bind_def 
                        select_def fail_def alternative_def split_def)
  done

lemma st_tcb_at_coerce_abstract:
  assumes t: "st_tcb_at' P t c"
  assumes sr: "(a, c) \<in> state_relation"
  shows "st_tcb_at (\<lambda>st. \<exists>st'. thread_state_relation st st' \<and> P st') t a"
  using assms
  apply (clarsimp simp: state_relation_def st_tcb_at'_def obj_at'_def
                        projectKOs objBits_simps)
  apply (erule(1) pspace_dom_relatedE)
  apply (erule(1) obj_relation_cutsE, simp_all)
  apply (clarsimp simp: st_tcb_at_def obj_at_def other_obj_relation_def
                        tcb_relation_def
                 split: Structures_A.kernel_object.split_asm
                        ARM_Structs_A.arch_kernel_obj.split_asm)
  apply fastforce
  done

lemma runnable_coerce_abstract:
  "\<lbrakk> runnable' st'; thread_state_relation st st' \<rbrakk>
    \<Longrightarrow> runnable st"
  by (case_tac st, simp_all)

lemma is_aligned_globals_2_strg:
  "valid_arch_state' s \<and> pspace_aligned' s \<longrightarrow> is_aligned (armKSGlobalsFrame (ksArchState s)) 2"
  unfolding valid_arch_state'_def
  apply (clarsimp simp: typ_at'_def ko_wp_at'_def pspace_aligned'_def)
  apply (drule (1) bspec [OF _ domI])
  apply (simp add: objBits_simps split: kernel_object.split_asm)
  apply (erule is_aligned_weaken)
  apply (simp add: pageBits_def)
  done

lemmas is_aligned_globals_2 =  is_aligned_globals_2_strg[THEN mp, OF conjI]

crunch armKSGlobalsFrame [wp]: setVMRoot "\<lambda>s. P (armKSGlobalsFrame (ksArchState s))"
  (simp: crunch_simps)

(* Levity: added (20090721 10:56:29) *)
declare objBitsT_koTypeOf [simp]

lemma arch_switch_thread_corres:
  "corres dc (valid_arch_state and valid_objs and valid_asid_map
              and valid_arch_objs and pspace_aligned and pspace_distinct
              and valid_vs_lookup and valid_global_objs
              and unique_table_refs o caps_of_state
              and st_tcb_at runnable t)
             (valid_arch_state' and valid_pspace' and st_tcb_at' runnable' t)
             (arch_switch_to_thread t) (ArchThreadDecls_H.switchToThread t)"
  apply (simp add: arch_switch_to_thread_def ArchThread_H.switchToThread_def)
  apply (rule corres_guard_imp)
    apply (rule corres_split' [OF set_vm_root_corres])
      apply (rule corres_split_eqr)
	 apply (rule corres_split_eqr [OF _ threadget_corres])
	    apply (rule corres_rel_imp)
             apply (rule corres_split_nor [OF _ store_word_corres])
               apply (rule corres_machine_op)
               apply (rule corres_Id[where r=dc], simp+)
               apply (simp add: MachineOps.clearExMonitor_def)
              apply wp
	    apply simp
	   apply (simp add: tcb_relation_def)
          apply wp
        apply (rule corres_trivial)
        apply (simp add: state_relation_def arch_state_relation_def)
       apply (wp | simp)+
      apply (strengthen split_state_strg [where P = "typ_at' UserDataT"])
      apply (wp hoare_vcg_ex_lift)
       apply (rule mp [OF is_aligned_globals_2_strg])
       apply clarsimp+
      apply (simp add: valid_arch_state'_def)
      apply (subst is_aligned_neg_mask_eq)
       apply (clarsimp dest!: typ_at_aligned' simp: objBitsT_simps)
      apply (clarsimp | rule TrueI)+
   apply (erule st_tcb_at_tcb_at)
  apply (clarsimp simp: valid_pspace'_def)
  done

lemma tcbSchedAppend_corres:
  notes trans_state_update'[symmetric, simp del]
  shows
  "corres dc (is_etcb_at t) (tcb_at' t and Invariants_H.valid_queues and valid_queues') (tcb_sched_action (tcb_sched_append) t) (tcbSchedAppend t)"
  apply (simp only: tcbSchedAppend_def tcb_sched_action_def)
  apply (rule corres_symb_exec_r [OF _ _ threadGet_inv, where Q'="\<lambda>rv. tcb_at' t and Invariants_H.valid_queues and valid_queues' and obj_at' (\<lambda>obj. tcbQueued obj = rv) t"])
    defer
    apply (wp threadGet_obj_at', simp, simp)
   apply (rule no_fail_pre, wp, simp)
  apply (case_tac queued)
   apply (simp add: unless_def when_def)
   apply (rule corres_no_failI)
    apply (rule no_fail_pre, wp)
   apply (clarsimp simp: in_monad ethread_get_def gets_the_def bind_assoc
                         assert_opt_def exec_gets is_etcb_at_def get_etcb_def get_tcb_queue_def
                         set_tcb_queue_def simpler_modify_def)
    
   apply (subgoal_tac "tcb_sched_append t (ready_queues a (tcb_domain y) (tcb_priority y))
                       = (ready_queues a (tcb_domain y) (tcb_priority y))")
    apply (simp add: state_relation_def ready_queues_relation_def)
   apply (clarsimp simp: tcb_sched_append_def state_relation_def 
                         valid_queues'_def ready_queues_relation_def
                         ekheap_relation_def etcb_relation_def
                         obj_at'_def inQ_def projectKO_eq project_inject)
   apply (drule_tac x=t in bspec,clarsimp)
   apply clarsimp
  apply (clarsimp simp: unless_def when_def cong: if_cong)
  apply (rule stronger_corres_guard_imp)
    apply (rule corres_split[where r'="op =", OF _ ethreadget_corres])
       apply (rule corres_split[where r'="op =", OF _ ethreadget_corres])
          apply (rule corres_split[where r'="op ="])
             apply (rule corres_split_noop_rhs2)
                apply (rule threadSet_corres_noop, simp_all add: tcb_relation_def exst_same_def)[1]
               apply (simp add: tcb_sched_append_def)
               apply (intro conjI impI)
                apply (rule corres_guard_imp)
                  apply (rule setQueue_corres)
                 prefer 3
                 apply (rule_tac P=\<top> and Q="K (t \<notin> set queuea)" in corres_assume_pre)
                 apply (wp getQueue_corres getObject_tcb_wp  | simp add: etcb_relation_def threadGet_def)+
  apply (fastforce simp: valid_queues_def obj_at'_def inQ_def 
                         projectKO_eq project_inject)
done


crunch valid_pspace'[wp]: tcbSchedEnqueue valid_pspace'
  (simp: unless_def)
crunch valid_pspace'[wp]: tcbSchedAppend valid_pspace'
  (simp: unless_def)
crunch valid_pspace'[wp]: tcbSchedDequeue valid_pspace'

crunch valid_arch_state'[wp]: tcbSchedEnqueue valid_arch_state'
  (simp: unless_def)
crunch valid_arch_state'[wp]: tcbSchedAppend valid_arch_state'
  (simp: unless_def)
crunch valid_arch_state'[wp]: tcbSchedDequeue valid_arch_state'

crunch st_tcb_at'[wp]: tcbSchedAppend "st_tcb_at' P t"
  (wp: threadSet_st_tcb_no_state simp: unless_def ignore: getObject setObject)
crunch st_tcb_at'[wp]: tcbSchedDequeue "st_tcb_at' P t"
  (wp: threadSet_st_tcb_no_state)

crunch state_refs_of'[wp]: setQueue "\<lambda>s. P (state_refs_of' s)"

lemma tcbSchedAppend_valid_queues[wp]:
  "\<lbrace>Invariants_H.valid_queues and st_tcb_at' runnable' t and valid_objs' \<rbrace>
     tcbSchedAppend t
   \<lbrace>\<lambda>_. Invariants_H.valid_queues\<rbrace>"
  apply (simp add: tcbSchedAppend_def setQueue_after)
  apply (rule hoare_pre)
   apply (rule_tac B="\<lambda>rv. Invariants_H.valid_queues and valid_objs'
                             and st_tcb_at' runnable' t
                             and obj_at' (\<lambda>obj. tcbQueued obj = rv) t
                             and st_tcb_at' runnable' t"
                in hoare_seq_ext)
    apply (rename_tac queued)
    apply (case_tac queued, simp_all add: unless_def when_def)[1]
     apply (wp setQueue_valid_queues threadSet_valid_queues hoare_vcg_const_Ball_lift threadGet_obj_at' threadGet_wp| simp)+
     apply clarsimp
     apply (frule valid_objs'_maxDomain, clarsimp, assumption)
     apply (frule valid_objs'_maxPriority, clarsimp, assumption)
     apply (fastforce simp: Invariants_H.valid_queues_def inQ_def obj_at'_def st_tcb_at'_def projectKOs valid_tcb'_def)
    apply (wp threadGet_wp)
    apply (fastforce simp: obj_at'_def st_tcb_at'_def)
done

lemma tcbSchedDequeue_valid_queues[wp]:
  "\<lbrace>Invariants_H.valid_queues
    and obj_at' (\<lambda>tcb. tcbDomain tcb \<le> maxDomain) t
    and obj_at' (\<lambda>tcb. tcbPriority tcb \<le> maxPriority) t\<rbrace>
     tcbSchedDequeue t
   \<lbrace>\<lambda>_. Invariants_H.valid_queues\<rbrace>"
  apply (simp add: tcbSchedDequeue_def)
  apply (rule hoare_pre)
   apply (rule_tac B="\<lambda>rv. Invariants_H.valid_queues
                           and obj_at' (\<lambda>tcb. tcbDomain tcb \<le> maxDomain) t
                           and obj_at' (\<lambda>tcb. tcbPriority tcb \<le> maxPriority) t
                           and obj_at' (\<lambda>obj. tcbQueued obj = rv) t"
                in hoare_seq_ext)
    apply (rename_tac queued)
    apply (case_tac queued, simp_all add: when_def)[1]
     apply (wp threadSet_valid_queues setQueue_valid_queues
          | simp add: setQueue_def)+
       apply (rule_tac Q="\<lambda>rv. Invariants_H.valid_queues
                           and obj_at' (\<lambda>tcb. tcbDomain tcb \<le> maxDomain) t
                           and obj_at' (\<lambda>tcb. tcbPriority tcb \<le> maxPriority) t
                           and obj_at' (\<lambda>tcb. tcbQueued tcb) t
                           and obj_at' (\<lambda>tcb. tcbPriority tcb = rv) t
                           and obj_at' (\<lambda>tcb. tcbDomain tcb = tdom) t"
                    in hoare_post_imp)
        apply (clarsimp simp: Invariants_H.valid_queues_def obj_at'_def inQ_def projectKOs)
       apply (wp threadGet_obj_at' | clarsimp simp: obj_at'_def)+
  done

lemma tcbSchedAppend_valid_queues'[wp]:
  "\<lbrace>valid_queues' and tcb_at' t\<rbrace> tcbSchedAppend t \<lbrace>\<lambda>_. valid_queues'\<rbrace>"
  apply (simp add: tcbSchedAppend_def)
  apply (rule hoare_pre)
   apply (rule_tac B="\<lambda>rv. valid_queues' and obj_at' (\<lambda>obj. tcbQueued obj = rv) t"
                in hoare_seq_ext)
    apply (rename_tac queued)
    apply (case_tac queued, simp_all add: unless_def when_def)[1]
     apply (wp threadSet_valid_queues' setQueue_valid_queues' | simp)+
      apply (rule_tac Q="\<lambda>rv. valid_queues'
                          and obj_at' (\<lambda>obj. \<not> tcbQueued obj) t
                          and obj_at' (\<lambda>obj. tcbPriority obj = prio) t
                          and obj_at' (\<lambda>obj. tcbDomain obj = tdom) t
                          and (\<lambda>s. t \<in> set (ksReadyQueues s (tdom, prio)))"
                   in hoare_post_imp)
       apply (clarsimp simp: valid_queues'_def obj_at'_def projectKOs inQ_def)
      apply (wp setQueue_valid_queues' | simp | simp add: setQueue_def)+
     apply (rule_tac Q="\<lambda>rv. valid_queues'
                         and obj_at' (\<lambda>obj. \<not> tcbQueued obj) t
                         and obj_at' (\<lambda>obj. tcbPriority obj = rv) t
                         and obj_at' (\<lambda>obj. tcbDomain obj = tdom) t"
                  in hoare_post_imp)
      apply (clarsimp simp: valid_queues'_def obj_at'_def inQ_def projectKOs)
     apply (wp threadGet_obj_at' | clarsimp simp: obj_at'_def)+
  done

crunch norq[wp]: threadSet "\<lambda>s. P (ksReadyQueues s)"
  (simp: updateObject_default_def ignore: setObject getObject)

lemma tcbSchedDequeue_valid_queues'[wp]:
  "\<lbrace>valid_queues' and tcb_at' t\<rbrace>
    tcbSchedDequeue t \<lbrace>\<lambda>_. valid_queues'\<rbrace>"
  apply (simp add: tcbSchedDequeue_def setQueue_after)
  apply (rule hoare_pre)
   apply (rule_tac B="\<lambda>rv. valid_queues' and obj_at' (\<lambda>obj. tcbQueued obj = rv) t"
                in hoare_seq_ext)
    apply (rename_tac queued)
    apply (case_tac queued, simp_all add: unless_def when_def)[1]
     apply (wp setQueue_valid_queues' | simp)+
       apply (rule_tac Q="\<lambda>rv. valid_queues'
                           and obj_at' (\<lambda>obj. \<not> tcbQueued obj) t
                           and obj_at' (\<lambda>obj. tcbPriority obj = prio) t
                           and obj_at' (\<lambda>obj. tcbDomain obj = tdom) t
                           and (\<lambda>s. ksReadyQueues s (tdom, prio) = queue)"
                    in hoare_post_imp)
        apply (clarsimp simp: valid_queues'_def obj_at'_def projectKOs inQ_def)
       apply (wp threadSet_valid_queues')
       apply (rule_tac Q="\<lambda>rv. valid_queues'
                           and obj_at' (\<lambda>obj. tcbQueued obj) t
                           and obj_at' (\<lambda>obj. tcbPriority obj = rv) t
                           and obj_at' (\<lambda>obj. tcbDomain obj = tdom) t"
                    in hoare_post_imp)
        apply (clarsimp simp: valid_queues'_def obj_at'_def inQ_def projectKOs)
       apply (wp threadGet_obj_at' | clarsimp simp: obj_at'_def)+
     apply (clarsimp simp: valid_queues'_def obj_at'_def inQ_def projectKOs)
     apply (wp threadGet_obj_at' | simp)+
  done

crunch tcb_at'[wp]: tcbSchedEnqueue "tcb_at' t"
  (simp: unless_def)
crunch tcb_at'[wp]: tcbSchedAppend "tcb_at' t"
  (simp: unless_def)
crunch tcb_at'[wp]: tcbSchedDequeue "tcb_at' t"

crunch nosch[wp]: tcbSchedEnqueue "\<lambda>s. P (ksSchedulerAction s)"
  (simp: unless_def)
crunch nosch[wp]: tcbSchedAppend "\<lambda>s. P (ksSchedulerAction s)"
  (simp: unless_def)
crunch nosch[wp]: tcbSchedDequeue "\<lambda>s. P (ksSchedulerAction s)"

crunch state_refs_of'[wp]: tcbSchedEnqueue "\<lambda>s. P (state_refs_of' s)"
  (wp: refl simp: crunch_simps unless_def)
crunch state_refs_of'[wp]: tcbSchedAppend "\<lambda>s. P (state_refs_of' s)"
  (wp: refl simp: crunch_simps unless_def)
crunch state_refs_of'[wp]: tcbSchedDequeue "\<lambda>s. P (state_refs_of' s)"
  (wp: refl simp: crunch_simps)

crunch cap_to'[wp]: tcbSchedEnqueue "ex_nonz_cap_to' p"
  (simp: unless_def)
crunch cap_to'[wp]: tcbSchedAppend "ex_nonz_cap_to' p"
  (simp: unless_def)
crunch cap_to'[wp]: tcbSchedDequeue "ex_nonz_cap_to' p"

crunch iflive'[wp]: setQueue if_live_then_nonz_cap'

lemma tcbSchedAppend_iflive'[wp]:
  "\<lbrace>if_live_then_nonz_cap' and ex_nonz_cap_to' tcb\<rbrace>
    tcbSchedAppend tcb \<lbrace>\<lambda>_. if_live_then_nonz_cap'\<rbrace>"
  apply (simp add: tcbSchedAppend_def unless_def)
  apply (wp threadSet_iflive' hoare_drop_imps | simp add: crunch_simps)+
  done

lemma tcbSchedDequeue_iflive'[wp]:
  "\<lbrace>if_live_then_nonz_cap'\<rbrace> tcbSchedDequeue tcb \<lbrace>\<lambda>_. if_live_then_nonz_cap'\<rbrace>"
  apply (simp add: tcbSchedDequeue_def)
  apply (wp threadSet_iflive' | simp)+
     apply (rule_tac Q="\<lambda>rv. \<top>" in hoare_post_imp, clarsimp)
     apply (wp | simp add: crunch_simps)+
  done

crunch ifunsafe'[wp]: tcbSchedEnqueue if_unsafe_then_cap'
  (simp: unless_def)
crunch ifunsafe'[wp]: tcbSchedAppend if_unsafe_then_cap'
  (simp: unless_def)
crunch ifunsafe'[wp]: tcbSchedDequeue if_unsafe_then_cap'

crunch idle'[wp]: tcbSchedEnqueue valid_idle'
  (simp: crunch_simps unless_def)
crunch idle'[wp]: tcbSchedAppend valid_idle'
  (simp: crunch_simps unless_def)
crunch idle'[wp]: tcbSchedDequeue valid_idle'
  (simp: crunch_simps)

crunch global_refs'[wp]: tcbSchedEnqueue valid_global_refs'
  (wp: threadSet_global_refs simp: unless_def ignore: getObject setObject)
crunch global_refs'[wp]: tcbSchedAppend valid_global_refs'
  (wp: threadSet_global_refs simp: unless_def)
crunch global_refs'[wp]: tcbSchedDequeue valid_global_refs'
  (wp: threadSet_global_refs)

crunch irq_node'[wp]: tcbSchedEnqueue "\<lambda>s. P (irq_node' s)"
  (simp: unless_def)
crunch irq_node'[wp]: tcbSchedAppend "\<lambda>s. P (irq_node' s)"
  (simp: unless_def)
crunch irq_node'[wp]: tcbSchedDequeue "\<lambda>s. P (irq_node' s)"

crunch typ_at'[wp]: tcbSchedEnqueue "\<lambda>s. P (typ_at' T p s)"
  (simp: unless_def)
crunch typ_at'[wp]: tcbSchedAppend "\<lambda>s. P (typ_at' T p s)"
  (simp: unless_def)
crunch typ_at'[wp]: tcbSchedDequeue "\<lambda>s. P (typ_at' T p s)"

crunch ctes_of[wp]: tcbSchedEnqueue "\<lambda>s. P (ctes_of s)"
  (simp: unless_def)
crunch ctes_of[wp]: tcbSchedAppend "\<lambda>s. P (ctes_of s)"
  (simp: unless_def)
crunch ctes_of[wp]: tcbSchedDequeue "\<lambda>s. P (ctes_of s)"

crunch ksInterrupt[wp]: tcbSchedEnqueue "\<lambda>s. P (ksInterruptState s)"
  (simp: unless_def)
crunch ksInterrupt[wp]: tcbSchedAppend "\<lambda>s. P (ksInterruptState s)"
  (simp: unless_def)
crunch ksInterrupt[wp]: tcbSchedDequeue "\<lambda>s. P (ksInterruptState s)"

crunch irq_states[wp]: tcbSchedEnqueue valid_irq_states'
  (simp: unless_def)
crunch irq_states[wp]: tcbSchedAppend valid_irq_states'
  (simp: unless_def)
crunch irq_states[wp]: tcbSchedDequeue valid_irq_states'

crunch ct'[wp]: tcbSchedEnqueue "\<lambda>s. P (ksCurThread s)"
  (simp: unless_def)
crunch ct'[wp]: tcbSchedAppend "\<lambda>s. P (ksCurThread s)"
  (simp: unless_def)
crunch ct'[wp]: tcbSchedDequeue "\<lambda>s. P (ksCurThread s)"

crunch pde_mappings'[wp]: tcbSchedEnqueue "valid_pde_mappings'"
  (simp: unless_def)
crunch pde_mappings'[wp]: tcbSchedAppend "valid_pde_mappings'"
  (simp: unless_def)
crunch pde_mappings'[wp]: tcbSchedDequeue "valid_pde_mappings'"

lemma tcbSchedEnqueue_vms'[wp]: 
  "\<lbrace>valid_machine_state'\<rbrace> tcbSchedEnqueue t \<lbrace>\<lambda>_. valid_machine_state'\<rbrace>"
  apply (simp add: valid_machine_state'_def pointerInUserData_def)
  apply (wp hoare_vcg_all_lift hoare_vcg_disj_lift tcbSchedEnqueue_ksMachine)
  done

crunch ksCurDomain[wp]: tcbSchedEnqueue "\<lambda>s. P (ksCurDomain s)"
(simp: unless_def)

lemma tcbSchedEnqueue_tcb_in_cur_domain'[wp]:
  "\<lbrace>tcb_in_cur_domain' t'\<rbrace> tcbSchedEnqueue t \<lbrace>\<lambda>_. tcb_in_cur_domain' t' \<rbrace>"
  apply (rule tcb_in_cur_domain'_lift)
   apply wp
  apply (clarsimp simp: tcbSchedEnqueue_def)
  apply wp
   apply (case_tac queued, simp_all add: unless_def when_def)
    apply (wp | simp)+
  done

lemma ct_idle_or_in_cur_domain'_lift2:
  "\<lbrakk> \<And>t. \<lbrace>tcb_in_cur_domain' t\<rbrace>         f \<lbrace>\<lambda>_. tcb_in_cur_domain' t\<rbrace>;
     \<And>P. \<lbrace>\<lambda>s. P (ksCurThread s) \<rbrace>       f \<lbrace>\<lambda>_ s. P (ksCurThread s) \<rbrace>;
     \<And>P. \<lbrace>\<lambda>s. P (ksIdleThread s) \<rbrace>      f \<lbrace>\<lambda>_ s. P (ksIdleThread s) \<rbrace>;
     \<And>P. \<lbrace>\<lambda>s. P (ksSchedulerAction s) \<rbrace> f \<lbrace>\<lambda>_ s. P (ksSchedulerAction s) \<rbrace>\<rbrakk>
   \<Longrightarrow> \<lbrace> ct_idle_or_in_cur_domain'\<rbrace> f \<lbrace>\<lambda>_. ct_idle_or_in_cur_domain' \<rbrace>"
  apply (unfold ct_idle_or_in_cur_domain'_def)
  apply (rule hoare_lift_Pf2[where f=ksCurThread])
  apply (rule hoare_lift_Pf2[where f=ksSchedulerAction])
  apply (wp static_imp_wp hoare_vcg_disj_lift )
  apply simp+
  done

lemma tcbSchedEnqueue_invs'[wp]:
  "\<lbrace>invs'
    and st_tcb_at' runnable' t
    and (\<lambda>s. ksSchedulerAction s = ResumeCurrentThread \<longrightarrow> ksCurThread s \<noteq> t)\<rbrace>
     tcbSchedEnqueue t
   \<lbrace>\<lambda>_. invs'\<rbrace>"
  apply (simp add: invs'_def valid_state'_def )
  apply (wp tcbSchedEnqueue_ct_not_inQ valid_irq_node_lift irqs_masked_lift hoare_vcg_disj_lift
            valid_irq_handlers_lift' cur_tcb_lift ct_idle_or_in_cur_domain'_lift2
       | simp add: cteCaps_of_def
       | auto elim!: st_tcb_ex_cap'' valid_objs'_maxDomain valid_objs'_maxPriority split: thread_state.split_asm simp: valid_pspace'_def)+
  done

lemma tcb_at'_has_tcbPriority:
 "tcb_at' t s \<Longrightarrow> \<exists>p. obj_at' (\<lambda>tcb. tcbPriority tcb = p) t s"
 by (clarsimp simp add: obj_at'_def)

lemma tcb_at'_has_tcbDomain:
 "tcb_at' t s \<Longrightarrow> \<exists>p. obj_at' (\<lambda>tcb. tcbDomain tcb = p) t s"
 by (clarsimp simp add: obj_at'_def)

lemma tcbSchedEnqueue_in_ksQ:
  "\<lbrace>valid_queues' and tcb_at' t\<rbrace> tcbSchedEnqueue t
   \<lbrace>\<lambda>r s. \<exists>domain priority. t \<in> set (ksReadyQueues s (domain, priority))\<rbrace>"
  apply (rule_tac Q="\<lambda>s. \<exists>d p. valid_queues' s \<and>
                             obj_at' (\<lambda>tcb. tcbPriority tcb = p) t s \<and>
                             obj_at' (\<lambda>tcb. tcbDomain tcb = d) t s"
           in hoare_pre_imp)
   apply (clarsimp simp: tcb_at'_has_tcbPriority tcb_at'_has_tcbDomain)
  apply (wp hoare_vcg_ex_lift)
  apply (simp add: tcbSchedEnqueue_def unless_def)
  apply (wp)
    apply (rule_tac Q="\<lambda>rv s. tdom = d \<and> rv = p \<and> obj_at' (\<lambda>tcb. tcbPriority tcb = p) t s
                            \<and> obj_at' (\<lambda>tcb. tcbDomain tcb = d) t s"
             in hoare_post_imp, clarsimp)
    apply (wp, wp threadGet_const)
  apply (rule_tac Q="\<lambda>rv s.
             obj_at' (\<lambda>tcb. tcbPriority tcb = p) t s \<and>
             obj_at' (\<lambda>tcb. tcbDomain tcb = d) t s \<and>
             obj_at' (\<lambda>tcb. tcbQueued tcb = rv) t s \<and>
             (rv \<longrightarrow> t \<in> set (ksReadyQueues s (d, p)))" in hoare_post_imp)
   apply (clarsimp simp: o_def elim!: obj_at'_weakenE)
  apply (wp threadGet_obj_at' hoare_vcg_imp_lift threadGet_const)
     apply (case_tac "obj_at' (Not \<circ> tcbQueued) t s")
      apply (clarsimp)
     apply (clarsimp simp: valid_queues'_def)
     apply (drule_tac x=d in spec)
     apply (drule_tac x=p in spec)
     apply (drule_tac x=t in spec)
     apply (subgoal_tac "obj_at' (inQ d p) t s", clarsimp)
     apply (clarsimp simp: obj_at'_def inQ_def)+
  done

crunch ksMachine[wp]: tcbSchedAppend "\<lambda>s. P (ksMachineState s)"
  (simp: unless_def)

lemma tcbSchedAppend_vms'[wp]:
  "\<lbrace>valid_machine_state'\<rbrace> tcbSchedAppend t \<lbrace>\<lambda>_. valid_machine_state'\<rbrace>"
  apply (simp add: valid_machine_state'_def pointerInUserData_def)
  apply (wp hoare_vcg_all_lift hoare_vcg_disj_lift tcbSchedAppend_ksMachine)
  done

crunch pspace_domain_valid[wp]: tcbSchedAppend "pspace_domain_valid"
  (simp: unless_def)

(* FIXME: Move to TcbAcc_R *)
lemma tcbSchedAppend_ct_not_inQ:
  "\<lbrace> ct_not_inQ and (\<lambda>s. t \<noteq> ksCurThread s) \<rbrace> tcbSchedAppend t \<lbrace> \<lambda>_. ct_not_inQ \<rbrace>"
  (is "\<lbrace>?PRE\<rbrace> _ \<lbrace>_\<rbrace>")
  proof -
    have ts: "\<lbrace>?PRE\<rbrace> threadSet (tcbQueued_update (\<lambda>_. True)) t \<lbrace>\<lambda>_. ct_not_inQ\<rbrace>"
      apply (simp add: ct_not_inQ_def)
      apply (rule hoare_weaken_pre)
       apply (wps setObject_ct_inv)
       apply (wp static_imp_wp, clarsimp simp: comp_def)
      done
    have sq: "\<And>p q. \<lbrace>ct_not_inQ\<rbrace> setQueue d p q \<lbrace>\<lambda>_. ct_not_inQ\<rbrace>"
      apply (simp add: ct_not_inQ_def setQueue_def)
      apply (wp)
      apply (clarsimp)
      done
    show ?thesis
      apply (simp add: tcbSchedAppend_def unless_def)
      apply (wp ts sq)
      apply (rule_tac Q="\<lambda>_. ?PRE" in hoare_post_imp, clarsimp)
      apply (wp)
      done
  qed

crunch ksCurDomain[wp]: tcbSchedAppend "\<lambda>s. P (ksCurDomain s)"
(simp: unless_def)

crunch ksIdleThread[wp]: tcbSchedAppend "\<lambda>s. P (ksIdleThread s)"
(simp: unless_def)

crunch ksDomSchedule[wp]: tcbSchedAppend "\<lambda>s. P (ksDomSchedule s)"
(simp: unless_def)

lemma tcbSchedAppend_tcbDomain[wp]:
  "\<lbrace> obj_at' (\<lambda>tcb. P (tcbDomain tcb)) t' \<rbrace>
     tcbSchedAppend t
   \<lbrace> \<lambda>_. obj_at' (\<lambda>tcb. P (tcbDomain tcb)) t' \<rbrace>"
  apply (clarsimp simp: tcbSchedAppend_def)
  apply wp
   apply (case_tac queued, simp_all add: unless_def when_def)
    apply (wp | simp)+
  done

lemma tcbSchedAppend_tcbPriority[wp]:
  "\<lbrace> obj_at' (\<lambda>tcb. P (tcbPriority tcb)) t' \<rbrace>
     tcbSchedAppend t
   \<lbrace> \<lambda>_. obj_at' (\<lambda>tcb. P (tcbPriority tcb)) t' \<rbrace>"
  apply (clarsimp simp: tcbSchedAppend_def)
  apply wp
   apply (case_tac queued, simp_all add: unless_def when_def)
    apply (wp | simp)+
  done

lemma tcbSchedAppend_tcb_in_cur_domain'[wp]:
  "\<lbrace>tcb_in_cur_domain' t'\<rbrace> tcbSchedAppend t \<lbrace>\<lambda>_. tcb_in_cur_domain' t' \<rbrace>"
  apply (rule tcb_in_cur_domain'_lift)
   apply wp
  done


crunch ksDomScheduleIdx[wp]: tcbSchedAppend "\<lambda>s. P (ksDomScheduleIdx s)"
  (simp: unless_def)

lemma tcbSchedAppend_invs'[wp]:
  "\<lbrace>invs' and st_tcb_at' runnable' t  and (\<lambda>s. t \<noteq> ksCurThread s) \<rbrace> tcbSchedAppend t \<lbrace>\<lambda>_. invs'\<rbrace>"
  apply (simp add: invs'_def valid_state'_def)
  apply (wp tcbSchedAppend_ct_not_inQ sch_act_wf_lift valid_irq_node_lift irqs_masked_lift
            valid_irq_handlers_lift' cur_tcb_lift ct_idle_or_in_cur_domain'_lift2
       | simp add: cteCaps_of_def
       | fastforce elim!: st_tcb_ex_cap'' split: thread_state.split_asm)+
  done

lemma tcbSchedAppend_invs_but_ct_not_inQ':
  "\<lbrace>invs' and st_tcb_at' runnable' t and tcb_in_cur_domain' t \<rbrace>
   tcbSchedAppend t \<lbrace>\<lambda>_. all_invs_but_ct_not_inQ'\<rbrace>"
  apply (simp add: invs'_def valid_state'_def)
  apply (wp sch_act_wf_lift valid_irq_node_lift irqs_masked_lift
            valid_irq_handlers_lift' cur_tcb_lift ct_idle_or_in_cur_domain'_lift2
       | simp add: cteCaps_of_def 
       | fastforce elim!: st_tcb_ex_cap'' split: thread_state.split_asm)+
  done

crunch ksMachine[wp]: tcbSchedDequeue "\<lambda>s. P (ksMachineState s)"
  (simp: unless_def)

lemma tcbSchedDequeue_vms'[wp]:
  "\<lbrace>valid_machine_state'\<rbrace> tcbSchedDequeue t \<lbrace>\<lambda>_. valid_machine_state'\<rbrace>"
  apply (simp add: valid_machine_state'_def pointerInUserData_def)
  apply (wp hoare_vcg_all_lift hoare_vcg_disj_lift tcbSchedDequeue_ksMachine)
  done

crunch pspace_domain_valid[wp]: tcbSchedDequeue "pspace_domain_valid"

crunch ksCurDomain[wp]: tcbSchedDequeue "\<lambda>s. P (ksCurDomain s)"
(simp: unless_def)

crunch ksIdleThread[wp]: tcbSchedDequeue "\<lambda>s. P (ksIdleThread s)"
(simp: unless_def)

crunch ksDomSchedule[wp]: tcbSchedDequeue "\<lambda>s. P (ksDomSchedule s)"
(simp: unless_def)

crunch ksDomScheduleIdx[wp]: tcbSchedDequeue "\<lambda>s. P (ksDomScheduleIdx s)"
(simp: unless_def)

lemma tcbSchedDequeue_tcb_in_cur_domain'[wp]:
  "\<lbrace>tcb_in_cur_domain' t'\<rbrace> tcbSchedDequeue t \<lbrace>\<lambda>_. tcb_in_cur_domain' t' \<rbrace>"
  apply (rule tcb_in_cur_domain'_lift)
   apply wp
  apply (clarsimp simp: tcbSchedDequeue_def)
  apply (wp hoare_when_weak_wp | simp)+
  done

lemma tcbSchedDequeue_tcbDomain[wp]:
  "\<lbrace> obj_at' (\<lambda>tcb. P (tcbDomain tcb)) t' \<rbrace>
     tcbSchedDequeue t
   \<lbrace> \<lambda>_. obj_at' (\<lambda>tcb. P (tcbDomain tcb)) t' \<rbrace>"
  apply (clarsimp simp: tcbSchedDequeue_def)
  apply (wp hoare_when_weak_wp | simp)+
  done

lemma tcbSchedDequeue_tcbPriority[wp]:
  "\<lbrace> obj_at' (\<lambda>tcb. P (tcbPriority tcb)) t' \<rbrace>
     tcbSchedDequeue t
   \<lbrace> \<lambda>_. obj_at' (\<lambda>tcb. P (tcbPriority tcb)) t' \<rbrace>"
  apply (clarsimp simp: tcbSchedDequeue_def)
  apply (wp hoare_when_weak_wp | simp)+
  done

lemma tcbSchedDequeue_invs'[wp]:
  "\<lbrace>invs' and tcb_at' t\<rbrace>
     tcbSchedDequeue t
   \<lbrace>\<lambda>_. invs'\<rbrace>"
  apply (simp add: invs'_def valid_state'_def )
  apply (wp tcbSchedDequeue_ct_not_inQ sch_act_wf_lift valid_irq_node_lift irqs_masked_lift
            valid_irq_handlers_lift' cur_tcb_lift ct_idle_or_in_cur_domain'_lift2
       | simp add: cteCaps_of_def )+
  apply (fastforce elim: valid_objs'_maxDomain valid_objs'_maxPriority simp: valid_pspace'_def)+
  done

lemma no_fail_isRunnable[wp]:
  "no_fail (tcb_at' t) (isRunnable t)"
  apply (simp add: isRunnable_def isBlocked_def)
  apply (rule no_fail_pre, wp)
  apply (clarsimp simp: st_tcb_at'_def)
  done

lemma corres_when_r:
  "\<lbrakk> G \<Longrightarrow> corres r P P' f g;
   \<not> G \<Longrightarrow> corres r Q Q' f (return ()) \<rbrakk>
  \<Longrightarrow> corres r (P and Q) (\<lambda>s. (G \<longrightarrow> P' s) \<and> (\<not>G \<longrightarrow> Q' s)) f (when G g)"
  apply (cases G, simp_all add: when_def)
   apply (rule corres_guard_imp, simp+)+
  done

lemma cur_thread_update_corres:
  "corres dc \<top> \<top> (modify (cur_thread_update (\<lambda>_. t))) (setCurThread t)"
  apply (unfold setCurThread_def)
  apply (rule corres_modify)
  apply (simp add: state_relation_def swp_def)
  done

lemma arch_switch_thread_tcb_at' [wp]: "\<lbrace>tcb_at' t\<rbrace> ArchThreadDecls_H.switchToThread t \<lbrace>\<lambda>_. tcb_at' t\<rbrace>"
  by (unfold ArchThread_H.switchToThread_def, wp typ_at_lift_tcb')

crunch typ_at'[wp]: "ThreadDecls_H.switchToThread" "\<lambda>s. P (typ_at' T p s)"
  (ignore: MachineOps.clearExMonitor)

lemma Arch_switchToThread_st_tcb'[wp]:
  "\<lbrace>\<lambda>s. P (st_tcb_at' P' t' s)\<rbrace>
   ArchThreadDecls_H.switchToThread t \<lbrace>\<lambda>rv s. P (st_tcb_at' P' t' s)\<rbrace>"
proof -
  have pos: "\<And>P t t'. \<lbrace>st_tcb_at' P t'\<rbrace> ArchThreadDecls_H.switchToThread t \<lbrace>\<lambda>rv. st_tcb_at' P t'\<rbrace>"
    apply (simp add: ArchThread_H.switchToThread_def storeWordUser_def st_tcb_at'_def)
    apply (wp doMachineOp_obj_at hoare_drop_imps)+
    done
  show ?thesis
    apply (rule P_bool_lift [OF pos])
    by (rule lift_neg_st_tcb_at' [OF ArchThreadDecls_H_switchToThread_typ_at' pos])
qed

crunch ksQ[wp]: storeWordUser "\<lambda>s. P (ksReadyQueues s p)"
crunch ksQ[wp]: setVMRoot "\<lambda>s. P (ksReadyQueues s)"
(wp: crunch_wps simp: crunch_simps)
crunch ksIdleThread[wp]: storeWordUser "\<lambda>s. P (ksIdleThread s)"

lemma arch_switch_thread_ksQ[wp]:
  "\<lbrace>\<lambda>s. P (ksReadyQueues s p)\<rbrace> ArchThreadDecls_H.switchToThread t \<lbrace>\<lambda>_ s. P (ksReadyQueues s p)\<rbrace>"
  apply (simp add: ArchThread_H.switchToThread_def)
  apply (wp)
  done

crunch valid_queues[wp]: "ArchThreadDecls_H.switchToThread" "Invariants_H.valid_queues"
(wp: crunch_wps simp: crunch_simps ignore: MachineOps.clearExMonitor)

(* FIXME: move to NonDetMonadVCG *)
lemma return_wp_exs_valid [wp]: "\<lbrace> P x \<rbrace> return x \<exists>\<lbrace> P \<rbrace>"
  by (simp add: exs_valid_def return_def)

(* FIXME: move to NonDetMonadVCG *)
lemma get_exs_valid [wp]: "\<lbrace>op = s\<rbrace> get \<exists>\<lbrace>\<lambda>r. op = s\<rbrace>"
  by (simp add: get_def exs_valid_def)

lemma switch_thread_corres:
  "corres dc (valid_arch_state and valid_objs and valid_asid_map 
                and valid_arch_objs and pspace_aligned and pspace_distinct 
                and valid_vs_lookup and valid_global_objs
                and unique_table_refs o caps_of_state
                and st_tcb_at runnable t and valid_etcbs)
             (valid_arch_state' and valid_pspace' and Invariants_H.valid_queues
                and st_tcb_at' runnable' t and cur_tcb')
             (switch_to_thread t) (switchToThread t)"
  (is "corres _ ?PA ?PH _ _")

proof -
  have mainpart: "corres dc (?PA) (?PH)
     (do y \<leftarrow> arch_switch_to_thread t;
         y \<leftarrow> (tcb_sched_action tcb_sched_dequeue t);
         modify (cur_thread_update (\<lambda>_. t))
      od)
     (do y \<leftarrow> ArchThreadDecls_H.switchToThread t;
         y \<leftarrow> tcbSchedDequeue t;
         setCurThread t
      od)"
    apply (rule corres_guard_imp)
      apply (rule corres_split [OF _ arch_switch_thread_corres])
        apply (rule corres_split[OF cur_thread_update_corres tcbSchedDequeue_corres])
         apply (wp|clarsimp simp: tcb_at_is_etcb_at st_tcb_at_tcb_at st_tcb_at')+
    done

  show ?thesis
    apply -
    apply (simp add: switch_to_thread_def switchToThread_def K_bind_def)
    apply (rule corres_symb_exec_l [where Q = "\<lambda> s rv. (?PA and op = rv) s",
                                    OF corres_symb_exec_l [OF mainpart]])
    apply (auto intro: no_fail_pre [OF no_fail_assert]
                      no_fail_pre [OF no_fail_get]
                dest: st_tcb_at_tcb_at [THEN get_tcb_at] |
           simp add: assert_def | wp)+
    done
qed

(* FIXME: move *)
lemma corres_gets_pre_lhs:
  "(\<And>x. corres r (P x) P' (g x) g') \<Longrightarrow>
  corres r (\<lambda>s. P (f s) s) P' (gets f >>= (\<lambda>x. g x)) g'"
  by (simp add: corres_underlying_gets_pre_lhs)

(* FIXME: move *)
lemma corres_if_lhs:
  assumes "P \<Longrightarrow> corres r A Q f f'"
  assumes "\<not>P \<Longrightarrow> corres r B Q g f'"
  shows "corres r (\<lambda>s. (P \<longrightarrow> A s) \<and> (\<not>P \<longrightarrow> B s)) Q (if P then f else g) f'"
  by (simp add: assms)

(* Levity: added (20090713 10:04:12) *)
declare sts_rel_idle [simp]

lemma allActiveTCBs_corres:
  assumes "\<And>threads. corres r (P threads) P' (m threads) m'"
  shows "corres r (\<lambda>s. P {x. getActiveTCB x s \<noteq> None} s) P' (do threads \<leftarrow> allActiveTCBs; m threads od) m'"
  apply (simp add: allActiveTCBs_def)
  apply (simp add: bind_def get_def)
  apply (insert assms)
  apply (simp add: corres_underlying_def)
  apply force
  done

lemma corres_gets_arch_globals:
  "corres (op =) \<top> \<top> (gets (arm_globals_frame \<circ> arch_state)) (gets (armKSGlobalsFrame \<circ> ksArchState))"
  by (simp add: state_relation_def arch_state_relation_def)

lemma typ_at'_typ_at'_mask: "\<And>s. \<lbrakk> typ_at' t (P s) s \<rbrakk> \<Longrightarrow>  typ_at' t (P s && ~~mask (objBitsT t)) s"
  apply (rule split_state_strg [where P = "typ_at' t", THEN mp])
  apply (frule typ_at_aligned')
  apply (clarsimp dest!: is_aligned_neg_mask_eq)
  done

lemma arch_switch_idle_thread_corres:
  "corres dc \<top> (valid_arch_state' and pspace_aligned') arch_switch_to_idle_thread ArchThreadDecls_H.switchToIdleThread"
  apply (simp add: arch_switch_to_idle_thread_def
                ArchThread_H.switchToIdleThread_def)
  apply (rule corres_guard_imp, rule corres_split[OF _ corres_gets_arch_globals])
      apply (simp, rule store_word_corres)
     apply (wp | clarsimp)+
  apply (clarsimp simp: is_aligned_globals_2)
  apply (fold objBitsT_simps)
  apply (rule typ_at'_typ_at'_mask)
  apply (clarsimp simp: valid_arch_state'_def)
  done

lemma switch_idle_thread_corres:
  "corres dc invs invs_no_cicd' switch_to_idle_thread switchToIdleThread"
  apply (simp add: switch_to_idle_thread_def switchToIdleThread_def)
  apply (rule corres_guard_imp)
    apply (rule corres_split [OF _ git_corres])
      apply (rule corres_split [OF _ arch_switch_idle_thread_corres])
        apply (unfold setCurThread_def)
        apply (rule corres_trivial, rule corres_modify)
        apply (simp add: state_relation_def cdt_relation_def)
       apply (wp, simp+)
  apply (simp add: all_invs_but_ct_idle_or_in_cur_domain'_def valid_state'_def valid_pspace'_def)
  done

lemma gq_sp: "\<lbrace>P\<rbrace> getQueue d p \<lbrace>\<lambda>rv. P and (\<lambda>s. ksReadyQueues s (d, p) = rv)\<rbrace>"
  by (unfold getQueue_def, rule gets_sp)

lemma gq_se: "\<lbrace>\<lambda>s'. (s, s') \<in> state_relation \<and> True\<rbrace> getQueue d p \<lbrace>\<lambda>rv s'. (s, s') \<in> state_relation\<rbrace>"
  by (simp add: getQueue_def)

lemma setQueue_no_change_ct[wp]:
  "\<lbrace>ct_in_state' st\<rbrace> setQueue d p q \<lbrace>\<lambda>rv. ct_in_state' st\<rbrace>"
  apply (simp add: setQueue_def)
  apply wp
  apply (simp add: ct_in_state'_def st_tcb_at'_def)
  done

lemma sch_act_wf:
  "sch_act_wf sa s = ((\<forall>t. sa = SwitchToThread t \<longrightarrow> st_tcb_at' runnable' t s \<and>
                                                    tcb_in_cur_domain' t s) \<and>
                      (sa = ResumeCurrentThread \<longrightarrow> ct_in_state' activatable' s))"
  by (case_tac sa,  simp_all add: )

declare gq_wp[wp]
declare setQueue_obj_at[wp]

lemma ready_tcb':
   "\<lbrakk> t \<in> set (ksReadyQueues s (d, p)); invs' s \<rbrakk>
        \<Longrightarrow> obj_at' (inQ d p) t s"
  apply (clarsimp simp: invs'_def valid_state'_def
                        valid_pspace'_def Invariants_H.valid_queues_def)
  apply (drule_tac x=d in spec)
  apply (drule_tac x=p in spec)
  apply (clarsimp)
  apply (drule(1) bspec)
  apply (erule obj_at'_weakenE)
  apply (simp)
  done

lemma ready_tcb_valid_queues:
   "\<lbrakk> t \<in> set (ksReadyQueues s (d, p)); valid_queues s \<rbrakk>
        \<Longrightarrow> obj_at' (inQ d p) t s"
  apply (clarsimp simp: invs'_def valid_state'_def
                        valid_pspace'_def Invariants_H.valid_queues_def)
  apply (drule_tac x=d in spec)
  apply (drule_tac x=p in spec)
  apply (clarsimp)
  apply (drule(1) bspec)
  apply (erule obj_at'_weakenE)
  apply (simp)
  done

lemma queued_vs_state[wp]:
  "\<lbrace>ct_in_state' st\<rbrace> threadSet (tcbQueued_update x) t \<lbrace>\<lambda>rv. ct_in_state' st\<rbrace>"
  apply (rule hoare_vcg_precond_imp)
   apply (rule hoare_post_imp[where Q="\<lambda>rv s. \<exists>t. t = ksCurThread s \<and> st_tcb_at' st t s"])
    apply (simp add: ct_in_state'_def)
   apply (unfold st_tcb_at'_def)
   apply (wp hoare_ex_wp threadSet_ct)
  apply (simp add: ct_in_state'_def st_tcb_at'_def)
  apply (erule obj_at'_weakenE)
  apply (case_tac k, simp)
  done

lemma threadSet_timeslice_invs:
  "\<lbrace>invs' and tcb_at' t\<rbrace> threadSet (tcbTimeSlice_update b) t \<lbrace>\<lambda>rv. invs'\<rbrace>"
  by (wp threadSet_invs_trivial, simp_all add: inQ_def cong: conj_cong)

(* Don't use this rule when considering the idle thread. The invariant ct_idle_or_in_cur_domain'
   says that either "tcb_in_cur_domain' t" or "t = ksIdleThread s".
   Use setCurThread_invs_idle_thread instead. *)
lemma setCurThread_invs:
  "\<lbrace>invs' and st_tcb_at' activatable' t and obj_at' (\<lambda>x. \<not> tcbQueued x) t and
    tcb_in_cur_domain' t\<rbrace> setCurThread t \<lbrace>\<lambda>rv. invs'\<rbrace>"
proof -
  have obj_at'_ct: "\<And>f P addr s.
       obj_at' P addr (ksCurThread_update f s) = obj_at' P addr s"
    by (fastforce intro: obj_at'_pspaceI)
  have valid_pspace'_ct: "\<And>s f.
       valid_pspace' (ksCurThread_update f s) = valid_pspace' s"
    by (rule valid_pspace'_ksPSpace, simp)
  have vms'_ct: "\<And>s f.
       valid_machine_state' (ksCurThread_update f s) = valid_machine_state' s"
    by (simp add: valid_machine_state'_def)
  have ct_not_inQ_ct: "\<And>s t . \<lbrakk> ct_not_inQ s; obj_at' (\<lambda>x. \<not> tcbQueued x) t s\<rbrakk> \<Longrightarrow> ct_not_inQ (s\<lparr> ksCurThread := t \<rparr>)"
    apply (simp add: ct_not_inQ_def o_def)
    done
  have tcb_in_cur_domain_ct: "\<And>s f t.
       tcb_in_cur_domain' t  (ksCurThread_update f s)= tcb_in_cur_domain' t s"
    by (fastforce simp: tcb_in_cur_domain'_def)
  show ?thesis
    apply (simp add: setCurThread_def)
    apply wp
    apply (clarsimp simp add: invs'_def cur_tcb'_def valid_state'_def obj_at'_ct
                              valid_pspace'_ct vms'_ct Invariants_H.valid_queues_def
                              sch_act_wf ct_in_state'_def state_refs_of'_def
                              ps_clear_def valid_irq_node'_def valid_queues'_def ct_not_inQ_ct
                              tcb_in_cur_domain_ct ct_idle_or_in_cur_domain'_def
                        cong: option.case_cong)
    done
qed


lemma valid_queues_not_runnable_not_queued:
  fixes s
  assumes vq:  "Invariants_H.valid_queues s"
      and vq': "valid_queues' s"
      and st: "st_tcb_at' (Not \<circ> runnable') t s"
  shows "obj_at' (Not \<circ> tcbQueued) t s"
proof (rule ccontr)
  assume "\<not> obj_at' (Not \<circ> tcbQueued) t s"
  moreover from st have "typ_at' TCBT t s"
    by (rule st_tcb_at' [THEN tcb_at_typ_at' [THEN iffD1]])
  ultimately have "obj_at' tcbQueued t s"
    by (clarsimp simp: not_obj_at' comp_def)

  moreover
  from st [THEN st_tcb_at', THEN tcb_at'_has_tcbPriority]
  obtain p where tp: "obj_at' (\<lambda>tcb. tcbPriority tcb = p) t s"
    by clarsimp

  moreover
  from st [THEN st_tcb_at', THEN tcb_at'_has_tcbDomain]
  obtain d where td: "obj_at' (\<lambda>tcb. tcbDomain tcb = d) t s"
    by clarsimp
  
  ultimately
  have "t \<in> set (ksReadyQueues s (d, p))" using vq'
    unfolding valid_queues'_def
    apply -
    apply (drule_tac x=d in spec)
    apply (drule_tac x=p in spec)
    apply (drule_tac x=t in spec)
    apply (erule impE)
     apply (fastforce simp add: inQ_def obj_at'_def)
    apply (assumption)
    done

  with vq have "st_tcb_at' runnable' t s"
    unfolding Invariants_H.valid_queues_def
    apply -
    apply (drule_tac x=d in spec)
    apply (drule_tac x=p in spec)
    apply (clarsimp simp add: st_tcb_at'_def)
    apply (drule(1) bspec)
    apply (erule obj_at'_weakenE)
    apply (clarsimp)
    done

  with st show False
    apply -
    apply (drule(1) st_tcb_at_conj')
    apply (clarsimp)
    done
qed

(*
 * The idle thread is not part of any ready queues.
 *)
lemma idle'_not_tcbQueued':
 assumes vq:   "Invariants_H.valid_queues s"
     and vq':  "valid_queues' s"
     and idle: "valid_idle' s"
 shows "obj_at' (Not \<circ> tcbQueued) (ksIdleThread s) s"
 proof -
   from idle have stidle: "st_tcb_at' (Not \<circ> runnable') (ksIdleThread s) s"
     apply (simp add: valid_idle'_def)
     apply (erule st_tcb'_weakenE)
     apply (simp)
     done

   with vq vq' show ?thesis
     by (rule valid_queues_not_runnable_not_queued)
 qed

lemma idle'_not_tcbQueued:
 assumes "invs' s"
 shows "obj_at' (Not \<circ> tcbQueued) (ksIdleThread s) s"
  by (insert assms)
     (clarsimp simp: invs'_def valid_state'_def
              elim!: idle'_not_tcbQueued')

lemma setCurThread_invs_idle_thread:
  "\<lbrace>invs' and (\<lambda>s. t = ksIdleThread s) \<rbrace> setCurThread t \<lbrace>\<lambda>rv. invs'\<rbrace>"
proof -
  have vms'_ct: "\<And>s f.
       valid_machine_state' (ksCurThread_update f s) = valid_machine_state' s"
    by (simp add: valid_machine_state'_def)
  have ct_not_inQ_ct: "\<And>s t . \<lbrakk> ct_not_inQ s; obj_at' (\<lambda>x. \<not> tcbQueued x) t s\<rbrakk> \<Longrightarrow> ct_not_inQ (s\<lparr> ksCurThread := t \<rparr>)"
    apply (simp add: ct_not_inQ_def o_def)
    done
  have idle'_activatable': "\<And> s t. st_tcb_at' idle' t s \<Longrightarrow> st_tcb_at' activatable' t s"
    apply (clarsimp simp: st_tcb_at'_def o_def obj_at'_def)
  done
  show ?thesis
    apply (simp add: setCurThread_def)
    apply wp
    apply (clarsimp simp add: vms'_ct ct_not_inQ_ct idle'_activatable' idle'_not_tcbQueued[simplified o_def]
                              invs'_def cur_tcb'_def valid_state'_def valid_idle'_def
                              Invariants_H.valid_queues_def
                              sch_act_wf ct_in_state'_def state_refs_of'_def
                              ps_clear_def valid_irq_node'_def valid_queues'_def
                               ct_idle_or_in_cur_domain'_def tcb_in_cur_domain'_def
                        cong: option.case_cong)
    done
qed

lemma clearExMonitor_invs'[wp]:
  "\<lbrace>invs'\<rbrace> doMachineOp MachineOps.clearExMonitor \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (wp dmo_invs')
   apply (simp add: no_irq_clearExMonitor)
  apply (clarsimp simp: MachineOps.clearExMonitor_def machine_op_lift_def
                        in_monad select_f_def)
  done

lemma Arch_switchToThread_invs:
  "\<lbrace>invs'\<rbrace> ArchThreadDecls_H.switchToThread t \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp add: ArchThread_H.switchToThread_def)
  apply wp
  done

lemma Arch_switchToThread_tcb':
  "\<lbrace>tcb_at' t\<rbrace> ArchThreadDecls_H.switchToThread t \<lbrace>\<lambda>rv. tcb_at' t\<rbrace>"
  apply (simp add: ArchThread_H.switchToThread_def storeWordUser_def)
  apply (wp doMachineOp_obj_at hoare_drop_imps)+
  done

crunch ksCurDomain[wp]: "ArchThreadDecls_H.switchToThread" "\<lambda>s. P (ksCurDomain s)"
(simp: whenE_def)

lemma Arch_swichToThread_tcbDomain_triv[wp]:
  "\<lbrace> obj_at' (\<lambda>tcb. P (tcbDomain tcb)) t' \<rbrace> ArchThreadDecls_H.switchToThread t \<lbrace> \<lambda>_. obj_at'  (\<lambda>tcb. P (tcbDomain tcb)) t' \<rbrace>"
  apply (clarsimp simp: ArchThread_H.switchToThread_def storeWordUser_def)
  apply (wp hoare_drop_imp | simp)+
  done

lemma Arch_swichToThread_tcbPriority_triv[wp]:
  "\<lbrace> obj_at' (\<lambda>tcb. P (tcbPriority tcb)) t' \<rbrace> ArchThreadDecls_H.switchToThread t \<lbrace> \<lambda>_. obj_at'  (\<lambda>tcb. P (tcbPriority tcb)) t' \<rbrace>"
  apply (clarsimp simp: ArchThread_H.switchToThread_def storeWordUser_def)
  apply (wp hoare_drop_imp | simp)+
  done

lemma Arch_switchToThread_tcb_in_cur_domain'[wp]:
  "\<lbrace>tcb_in_cur_domain' t'\<rbrace> ArchThreadDecls_H.switchToThread t \<lbrace>\<lambda>_. tcb_in_cur_domain' t' \<rbrace>"
  apply (rule tcb_in_cur_domain'_lift)
   apply wp
  done

lemma tcbSchedDequeue_not_tcbQueued:
  "\<lbrace> tcb_at' t \<rbrace> tcbSchedDequeue t \<lbrace> \<lambda>_. obj_at' (\<lambda>x. \<not> tcbQueued x) t \<rbrace>"
  apply (simp add: tcbSchedDequeue_def)
  apply (wp)
  apply (rule_tac Q="\<lambda>queued. obj_at' (\<lambda>x. tcbQueued x = queued) t" in hoare_post_imp)
   apply (clarsimp simp: obj_at'_def)
  apply (wp threadGet_obj_at')
  apply (simp)
  done

lemma switchToThread_invs[wp]:
  "\<lbrace>invs' and st_tcb_at' runnable' t and tcb_in_cur_domain' t \<rbrace> switchToThread t \<lbrace>\<lambda>rv. invs' \<rbrace>"
  apply (simp add: switchToThread_def )
  apply (wp threadSet_timeslice_invs setCurThread_invs
             Arch_switchToThread_invs Arch_switchToThread_st_tcb'
             dmo_invs' doMachineOp_obj_at tcbSchedDequeue_not_tcbQueued)
  by (clarsimp elim!: st_tcb'_weakenE)+

lemma setCurThread_ct_in_state:
  "\<lbrace>obj_at' (P \<circ> tcbState) t\<rbrace> setCurThread t \<lbrace>\<lambda>rv. ct_in_state' P\<rbrace>"
proof -
  have obj_at'_ct: "\<And>P addr f s.
       obj_at' P addr (ksCurThread_update f s) = obj_at' P addr s"
    by (fastforce intro: obj_at'_pspaceI)
  show ?thesis
    apply (simp add: setCurThread_def)
    apply wp
    apply (simp add: ct_in_state'_def st_tcb_at'_def obj_at'_ct)
    done
qed

lemma Arch_switchToThread_obj_at:
  "\<lbrace>obj_at' (P \<circ> tcbState) t\<rbrace>
   ArchThreadDecls_H.switchToThread t
   \<lbrace>\<lambda>rv. obj_at' (P \<circ> tcbState) t\<rbrace>"
  apply (simp add: ArchThread_H.switchToThread_def storeWordUser_def)
  apply (wp doMachineOp_obj_at setVMRoot_obj_at hoare_drop_imps)
  done

lemma switchToThread_ct_in_state[wp]:
  "\<lbrace>obj_at' (P \<circ> tcbState) t\<rbrace> switchToThread t \<lbrace>\<lambda>rv. ct_in_state' P\<rbrace>"
proof -
  have P: "\<And>f x. tcbState (tcbTimeSlice_update f x) = tcbState x"
    by (case_tac x, simp)
  show ?thesis
    apply (simp add: switchToThread_def tcbSchedEnqueue_def unless_def)
    apply (wp setCurThread_ct_in_state Arch_switchToThread_obj_at
         | simp add: P o_def cong: if_cong)+
    done
qed

lemma setCurThread_obj_at[wp]:
  "\<lbrace>obj_at' P addr\<rbrace> setCurThread t \<lbrace>\<lambda>rv. obj_at' P addr\<rbrace>"
  apply (simp add: setCurThread_def)
  apply wp
  apply (fastforce intro: obj_at'_pspaceI)
  done

lemma switchToThread_tcb'[wp]:
  "\<lbrace>tcb_at' t\<rbrace> switchToThread t \<lbrace>\<lambda>rv. tcb_at' t\<rbrace>"
  apply (simp add: Thread_H.switchToThread_def when_def)
  apply wp
  done

declare doMachineOp_obj_at[wp]

crunch cap_to'[wp]: setQueue "ex_nonz_cap_to' p"

lemma dmo_cte_wp_at'[wp]:
  "\<lbrace>cte_wp_at' P p\<rbrace> doMachineOp m \<lbrace>\<lambda>rv. cte_wp_at' P p\<rbrace>"
  apply (simp add: doMachineOp_def split_def)
  apply wp
  apply (clarsimp elim!: cte_wp_at'_pspaceI)
  done

lemma dmo_cap_to'[wp]:
  "\<lbrace>ex_nonz_cap_to' p\<rbrace>
     doMachineOp m
   \<lbrace>\<lambda>rv. ex_nonz_cap_to' p\<rbrace>"
  by (wp ex_nonz_cap_to_pres')

lemma sct_cap_to'[wp]:
  "\<lbrace>ex_nonz_cap_to' p\<rbrace> setCurThread t \<lbrace>\<lambda>rv. ex_nonz_cap_to' p\<rbrace>"
  apply (simp add: setCurThread_def)
  apply (wp ex_nonz_cap_to_pres')
  apply (clarsimp elim!: cte_wp_at'_pspaceI)
  done

crunch cap_to'[wp]: switchToThread "ex_nonz_cap_to' p"
  (simp: crunch_simps ignore: MachineOps.clearExMonitor)

lemma no_longer_inQ[simp]:
  "\<not> inQ d p (tcbQueued_update (\<lambda>x. False) tcb)"
  by (simp add: inQ_def)

lemma rq_distinct:
  "invs' s \<Longrightarrow> distinct (ksReadyQueues s (d, p))"
  by (clarsimp simp: invs'_def valid_state'_def Invariants_H.valid_queues_def)

lemma iflive_inQ_nonz_cap_strg:
  "if_live_then_nonz_cap' s \<and> obj_at' (inQ d prio) t s
          \<longrightarrow> ex_nonz_cap_to' t s"
  by (clarsimp simp: obj_at'_real_def projectKOs inQ_def
              elim!: if_live_then_nonz_capE' ko_wp_at'_weakenE)

lemmas iflive_inQ_nonz_cap[elim]
    = mp [OF iflive_inQ_nonz_cap_strg, OF conjI[rotated]]

crunch ksRQ[wp]: threadSet "\<lambda>s. P (ksReadyQueues s)"
  (ignore: setObject getObject
       wp: updateObject_default_inv)

declare Cons_eq_tails[simp]

lemma invs_ksReadyQueues_update_triv:
  "\<lbrakk> \<forall>d p. set (f (ksReadyQueues s) (d,p)) = set (ksReadyQueues s (d,p));
     \<forall>d p. distinct (f (ksReadyQueues s) (d,p)) = distinct (ksReadyQueues s (d,p));
     \<forall>d p. (d > maxDomain \<or> p > maxPriority \<longrightarrow> (f (ksReadyQueues s) (d,p) = [])) = (d > maxDomain \<or> p > maxPriority \<longrightarrow> (ksReadyQueues s (d,p) = []))
 \<rbrakk>
      \<Longrightarrow> invs' (ksReadyQueues_update f s) = invs' s"
  by (auto simp add: invs'_def valid_state'_def ct_not_inQ_def
                     valid_irq_node'_def cur_tcb'_def
                     Invariants_H.valid_queues_def valid_queues'_def
                     ct_idle_or_in_cur_domain'_def tcb_in_cur_domain'_def)

lemma tcbSchedDequeue_ksReadyQueues_eq:
  "\<lbrace>\<lambda>s. obj_at' (inQ d p) t s \<and> filter (op \<noteq> t) (ksReadyQueues s (d, p)) = ts\<rbrace>
      tcbSchedDequeue t
   \<lbrace>\<lambda>rv s. ksReadyQueues s (d, p) = ts\<rbrace>"
  apply (simp add: tcbSchedDequeue_def threadGet_def liftM_def)
  apply (wp getObject_tcb_wp)
  apply (clarsimp simp: obj_at'_def projectKOs inQ_def split del: split_if)
  apply (simp add: eq_commute)
  done

declare static_imp_wp[wp_split del]

lemma hd_ksReadyQueues_runnable:
  "\<lbrakk>invs' s; ksReadyQueues s (d, p) = a # as\<rbrakk>
     \<Longrightarrow> st_tcb_at' runnable' a s"
  apply(simp add: invs'_def valid_state'_def, rule valid_queues_running, clarsimp)
   apply(rule suffixeq_Cons_mem)
   apply(simp add: suffixeq_def)
   apply(rule exI)
   apply(rule eq_Nil_appendI)
   by auto

lemma chooseThread_invs_fragment: "\<lbrace>invs' and (\<lambda>s. ksCurDomain s = d)\<rbrace>
       do x \<leftarrow> getQueue d r;
        (case x of [] \<Rightarrow> return False
          | thread # x \<Rightarrow> do y \<leftarrow> ThreadDecls_H.switchToThread thread; return True od)
       od
       \<lbrace>\<lambda>_. invs'\<rbrace>"
  apply (rule seq_ext)
   apply (rule gq_sp)
  apply (case_tac x)
   apply (simp)
   apply (wp)
   apply (clarsimp)
  apply (simp)
  apply (wp)
  apply (clarsimp simp: invs'_def valid_state'_def , rule conjI)
   apply (rule valid_queues_running)
    apply (rule suffixeq_Cons_mem)
    apply (simp add: suffixeq_def)
    apply (rule exI)
    apply (rule eq_Nil_appendI)
    apply simp+
  apply (simp add: tcb_in_cur_domain'_def valid_queues_def)
  apply (drule_tac x="ksCurDomain s" in spec)
  apply (drule_tac x=r in spec)
  apply (fastforce simp: obj_at'_def inQ_def)
  done

crunch ksCurDomain[wp]: "ThreadDecls_H.switchToThread" "\<lambda>s. P (ksCurDomain s)"

lemma chooseThread_ksCurDomain_fragment:
  "\<lbrace>\<lambda>s. P (ksCurDomain s)\<rbrace>
       do x \<leftarrow> getQueue d r;
        (case x of [] \<Rightarrow> return False
          | thread # x \<Rightarrow> do y \<leftarrow> ThreadDecls_H.switchToThread thread; return True od)
       od
   \<lbrace>\<lambda>_ s. P (ksCurDomain s)\<rbrace>"
  apply (wp | wpc | clarsimp)+
  done

lemma obj_tcb_at':
  "obj_at' (\<lambda>tcb::tcb. P tcb) t s \<Longrightarrow> tcb_at' t s"
  by (clarsimp simp: obj_at'_def)

lemma valid_queues_queued_runnable:
  fixes s
  assumes vq:  "Invariants_H.valid_queues s"
      and vq': "valid_queues' s"
      and oa:  "obj_at' tcbQueued t s"
  shows "st_tcb_at' runnable' t s"
proof -
  from oa [THEN obj_tcb_at', THEN tcb_at'_has_tcbPriority]
  obtain p where tp: "obj_at' (\<lambda>tcb. tcbPriority tcb = p) t s"
    by clarsimp

  from oa [THEN obj_tcb_at', THEN tcb_at'_has_tcbDomain]
  obtain d where td: "obj_at' (\<lambda>tcb. tcbDomain tcb = d) t s"
    by clarsimp

  with oa tp have "obj_at' (inQ d p) t s"
    by (fastforce simp add: inQ_def obj_at'_def)
  
  with vq' have "t \<in> set (ksReadyQueues s (d, p))"
    unfolding valid_queues'_def
    by (fastforce)

  with vq show ?thesis
    unfolding Invariants_H.valid_queues_def
    apply -
    apply (drule_tac x=d in spec)
    apply (drule_tac x=p in spec)
    apply (clarsimp simp: st_tcb_at'_def)
    apply (drule(1) bspec)
    apply (erule obj_at'_weakenE)
    apply (simp)
    done
qed

lemma tcb_at_typ_at':
  "tcb_at' p s = typ_at' TCBT p s"
  unfolding typ_at'_def
  apply rule
  apply (clarsimp simp add: obj_at'_def ko_wp_at'_def projectKOs)
  apply (clarsimp simp add: obj_at'_def ko_wp_at'_def projectKOs)
  apply (case_tac ko, simp_all)
  done



lemma invs'_not_runnable_not_queued:
  fixes s
  assumes inv: "invs' s"
      and st: "st_tcb_at' (Not \<circ> runnable') t s"
  shows "obj_at' (Not \<circ> tcbQueued) t s"
  apply (insert assms)
  apply (rule valid_queues_not_runnable_not_queued)
    apply (clarsimp simp add: invs'_def valid_state'_def)+
  done

lemma valid_queues_not_tcbQueued_not_ksQ:
  fixes s
  assumes   vq: "Invariants_H.valid_queues s"
      and notq: "obj_at' (Not \<circ> tcbQueued) t s"
  shows "\<forall>d p. t \<notin> set (ksReadyQueues s (d, p))"
proof (rule ccontr, simp , erule exE, erule exE)
  fix d p
  assume "t \<in> set (ksReadyQueues s (d, p))"
  with vq have "obj_at' (inQ d p) t s"
    unfolding Invariants_H.valid_queues_def
    apply -
    apply (drule_tac x=d in spec)
    apply (drule_tac x=p in spec)
    apply (clarsimp)
    apply (drule(1) bspec)
    apply (erule obj_at'_weakenE)
    apply (simp)
    done
  hence "obj_at' tcbQueued t s"
    apply (rule obj_at'_weakenE)
    apply (simp only: inQ_def)
    done
  with notq show "False"
    by (clarsimp simp: obj_at'_def)
qed

lemma not_tcbQueued_not_ksQ:
  fixes s
  assumes "invs' s"
      and "obj_at' (Not \<circ> tcbQueued) t s"
  shows "\<forall>d p. t \<notin> set (ksReadyQueues s (d, p))"
  apply (insert assms)
  apply (clarsimp simp add: invs'_def valid_state'_def)
  apply (drule(1) valid_queues_not_tcbQueued_not_ksQ)
  apply (clarsimp)
  done

lemma ct_not_ksQ:
  "\<lbrakk> invs' s; ksSchedulerAction s = ResumeCurrentThread \<rbrakk>
   \<Longrightarrow> \<forall>p. ksCurThread s \<notin> set (ksReadyQueues s p)"
  apply (clarsimp simp: invs'_def valid_state'_def ct_not_inQ_def)
  apply (frule(1) valid_queues_not_tcbQueued_not_ksQ)
  apply (fastforce)
  done

crunch nosch[wp]: getCurThread "\<lambda>s. P (ksSchedulerAction s)"

lemma setThreadState_rct:
  "\<lbrace>\<lambda>s. (runnable' st \<or> ksCurThread s \<noteq> t)
        \<and> ksSchedulerAction s = ResumeCurrentThread\<rbrace>
   setThreadState st t
   \<lbrace>\<lambda>_ s. ksSchedulerAction s = ResumeCurrentThread\<rbrace>"
  apply (simp add: setThreadState_def)
  apply (rule hoare_pre_disj')
   apply (rule hoare_seq_ext [OF _
                 hoare_vcg_conj_lift
                   [OF threadSet_tcbState_st_tcb_at' [where P=runnable']
                       threadSet_nosch]])
   apply (rule hoare_seq_ext [OF _
                 hoare_vcg_conj_lift [OF isRunnable_const isRunnable_inv]])
   apply (clarsimp simp: when_def)
   apply (case_tac x)
    apply (clarsimp, wp)[1]
   apply (clarsimp)
  apply (rule hoare_seq_ext [OF _
                hoare_vcg_conj_lift
                  [OF threadSet_ct threadSet_nosch]])
  apply (rule hoare_seq_ext [OF _ isRunnable_inv])
  apply (rule hoare_seq_ext [OF _
                hoare_vcg_conj_lift
                  [OF gct_wp getCurThread_nosch]])
  apply (rename_tac ct)
  apply (case_tac "ct\<noteq>t")
   apply (clarsimp simp: when_def)
   apply (wp)[1]
  apply (clarsimp)
  done

lemma switchToIdleThread_invs'[wp]:
  "\<lbrace>invs'\<rbrace> switchToIdleThread \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (clarsimp simp: switchToIdleThread_def ArchThread_H.switchToIdleThread_def)
  apply (wp_trace setCurThread_invs_idle_thread)
  apply clarsimp
  done

lemma bind_dummy_ret_val:
  "do y \<leftarrow> a;
      b
   od = do a; b od"
  by simp

lemma chooseThread_invs':
  "\<lbrace>invs'\<rbrace> chooseThread \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp add: chooseThread_def Let_def curDomain_def cong: if_cong)
  apply (rule hoare_seq_ext [OF _ gets_sp])
  apply (wp, simp)
  apply (rule hoare_strengthen_post[OF findM_inv])
  apply (rule hoare_elim_pred_conj[OF hoare_conjI])
   apply (wp chooseThread_invs_fragment chooseThread_ksCurDomain_fragment |wpc | simp)+
  done

crunch obj_at'[wp]: "ArchThreadDecls_H.switchToIdleThread" "\<lambda>s. obj_at' P t s"

lemma switchToIdleThread_activatable[wp]:
  "\<lbrace>invs'\<rbrace> switchToIdleThread \<lbrace>\<lambda>rv. ct_in_state' activatable'\<rbrace>"
  apply (simp add: switchToIdleThread_def
                   ArchThread_H.switchToIdleThread_def)
  apply (wp setCurThread_ct_in_state)
  apply (clarsimp simp: invs'_def valid_state'_def valid_idle'_def
                        st_tcb_at'_def obj_at'_def)
  done

declare static_imp_conj_wp[wp_split del]

lemma valid_queues_obj_at'_imp:
   "\<lbrakk> t \<in> set (ksReadyQueues s (d, p)); Invariants_H.valid_queues s; \<And>obj. runnable' obj \<Longrightarrow> P obj \<rbrakk>
        \<Longrightarrow> obj_at' (P \<circ> tcbState) t s"
  apply (clarsimp simp: Invariants_H.valid_queues_def o_def)
  apply(elim allE conjE)
  apply(rule obj_at'_weaken)
   apply(erule(1) ballE)
   apply(erule(1) notE)
  apply(clarsimp simp: obj_at'_def inQ_def)
done

lemma chooseThread_activatable:
  "\<lbrace>invs'\<rbrace> chooseThread \<lbrace>\<lambda>rv. ct_in_state' activatable'\<rbrace>"
  apply (simp add: chooseThread_def Let_def cong: if_cong)
  apply (wp)
  apply (rule hoare_weaken_pre)
  apply (rule findM_on_outcome [where I="invs'"])
   apply (rename_tac prio ys)
   apply(clarsimp)
   apply (wp, wpc, wp)
    apply (clarsimp)
    apply (wp switchToThread_ct_in_state)
   apply (clarsimp)
   apply (drule(1) hd_ksReadyQueues_runnable)
   apply (simp only: st_tcb_at'_def)
   apply (erule obj_at'_weakenE)
   apply (simp add: curDomain_def)+
  done

lemma setCurThread_const:
  "\<lbrace>\<lambda>_. P t \<rbrace> setCurThread t \<lbrace>\<lambda>_ s. P (ksCurThread s) \<rbrace>"
  by (simp add: setCurThread_def | wp)+

crunch it[wp]: switchToIdleThread "\<lambda>s. P (ksIdleThread s)"
crunch it[wp]: switchToThread "\<lambda>s. P (ksIdleThread s)"
    (ignore: MachineOps.clearExMonitor)

lemma switchToIdleThread_curr_is_idle:
  "\<lbrace>\<top>\<rbrace> switchToIdleThread \<lbrace>\<lambda>rv s. ksCurThread s = ksIdleThread s\<rbrace>"
  apply (rule hoare_weaken_pre)
   apply (wps switchToIdleThread_it)
   apply (simp add: switchToIdleThread_def)
   apply (wp setCurThread_const)
  apply (simp)
 done

lemma chooseThread_it[wp]:
  "\<lbrace>\<lambda>s. P (ksIdleThread s)\<rbrace> chooseThread \<lbrace>\<lambda>_ s. P (ksIdleThread s)\<rbrace>"
  apply (simp add: chooseThread_def curDomain_def)
  apply (wp)
  apply (clarsimp)
   apply (rule findM_on_outcome [where I="\<top>"])
   apply (clarsimp)
   apply (wp, wpc, wp)
   apply (clarsimp)+
  done

lemma valid_queues_ct_update[simp]:
  "Invariants_H.valid_queues (s\<lparr>ksCurThread := t\<rparr>) = Invariants_H.valid_queues s"
  by (simp add: Invariants_H.valid_queues_def)

lemma valid_queues'_ct_update[simp]:
  "valid_queues' (s\<lparr>ksCurThread := t\<rparr>) = valid_queues' s"
  by (simp add: valid_queues'_def)

lemma valid_machine_state'_ct_update[simp]:
  "valid_machine_state' (s\<lparr>ksCurThread := t\<rparr>) = valid_machine_state' s"
  by (simp add: valid_machine_state'_def)

lemma valid_irq_node'_ct_update[simp]:
  "valid_irq_node' w (s\<lparr>ksCurThread := t\<rparr>) = valid_irq_node' w s"
  by (simp add: valid_irq_node'_def)

lemma switchToThread_ct_not_queued:
  "\<lbrace>invs' and tcb_at' t\<rbrace> switchToThread t \<lbrace>\<lambda>rv s. obj_at' (Not \<circ> tcbQueued) (ksCurThread s) s\<rbrace>"
  (is "\<lbrace>_\<rbrace> _ \<lbrace>\<lambda>_. ?POST\<rbrace>")
  apply (simp add: switchToThread_def)
  apply (wp)
    apply (simp add: switchToThread_def setCurThread_def)
    apply (wp tcbSchedDequeue_not_tcbQueued | simp )+
  done

lemma valid_irq_node'_ksCurThread: "valid_irq_node' w (s\<lparr>ksCurThread := t\<rparr>) = valid_irq_node' w s"
  unfolding valid_irq_node'_def
  by simp

lemma chooseThread_ct_not_queued:
  "\<lbrace>invs'\<rbrace> chooseThread \<lbrace>\<lambda>rv s. obj_at' (Not \<circ> tcbQueued) (ksCurThread s) s\<rbrace>"
  (is "\<lbrace>_\<rbrace> _ \<lbrace>\<lambda>_. ?POST\<rbrace>")
  apply (simp add: chooseThread_def curDomain_def)
  apply (rule hoare_seq_ext [OF _ gets_sp])
  apply (wp)
   apply (rule_tac Q="\<lambda>_ s. ksCurThread s = ksIdleThread s
                            \<and> obj_at' (Not \<circ> tcbQueued) (ksIdleThread s) s"
            in hoare_post_imp, clarsimp)
   apply (wp switchToIdleThread_curr_is_idle)
   apply (wps switchToIdleThread_it)
   apply (simp add: switchToIdleThread_def
                    ArchThread_H.switchToIdleThread_def)
   apply (wp)
   apply (rule hoare_weaken_pre)
   apply (rule_tac I="invs' and (\<lambda>s. ksCurDomain s = curdom)" in  findM_on_outcome)
   apply (clarsimp)
   apply (wp | wpc | clarsimp)+
    apply (wp switchToThread_ct_not_queued)
   apply (clarsimp)
   apply (frule(1) hd_ksReadyQueues_runnable)
   apply (clarsimp)+
  apply (erule idle'_not_tcbQueued)
  done

lemma threadGet_inv [wp]: "\<lbrace>P\<rbrace> threadGet f t \<lbrace>\<lambda>rv. P\<rbrace>"
  apply (simp add: threadGet_def)
  apply (wp | simp)+
  done

lemma getThreadState_ct_in_state:
  "\<lbrace>\<lambda>s. t = ksCurThread s \<and> tcb_at' t s\<rbrace> getThreadState t \<lbrace>\<lambda>rv s. P rv \<longrightarrow> ct_in_state' P s\<rbrace>"
  apply (rule hoare_post_imp [where Q="\<lambda>rv s. t = ksCurThread s \<and> ((\<not> P rv) \<or> st_tcb_at' P t s)"])
   apply (clarsimp simp add: ct_in_state'_def)
  apply (rule hoare_vcg_precond_imp)
   apply (wp hoare_vcg_disj_lift)
  apply (clarsimp simp add: st_tcb_at'_def obj_at'_def)
  done

lemma gsa_wf_invs:
  "\<lbrace>invs'\<rbrace> getSchedulerAction \<lbrace>\<lambda>sa. invs' and sch_act_wf sa\<rbrace>"
  by wp (clarsimp simp add: invs'_def valid_state'_def)

(* Helper for schedule_corres *)
lemma gsa_wf_invs_and_P:
  "\<lbrace>invs' and P\<rbrace> getSchedulerAction \<lbrace>\<lambda>sa. invs' and P
                                                and (\<lambda>s. ksSchedulerAction s = sa)
                                                and sch_act_wf sa\<rbrace>"
  apply ( wp |  simp )
  by auto

lemma gets_the_simp:
  "f s = Some y \<Longrightarrow> gets_the f s = ({(y, s)}, False)"
  by (simp add: gets_the_def gets_def assert_opt_def get_def bind_def return_def fail_def split: option.splits)

lemma corres_split_sched_act:
  "\<lbrakk>sched_act_relation act act';
    corres r P P' f1 g1;
    \<And>t. corres r (Q t) (Q' t) (f2 t) (g2 t);
    corres r R R' f3 g3\<rbrakk>
    \<Longrightarrow> corres r (case act of resume_cur_thread \<Rightarrow> P
                           | switch_thread t \<Rightarrow> Q t
                           | choose_new_thread \<Rightarrow> R)
               (case act' of ResumeCurrentThread \<Rightarrow> P'
                           | SwitchToThread t \<Rightarrow> Q' t
                           | ChooseThread \<Rightarrow> R')
       (case act of resume_cur_thread \<Rightarrow> f1
                  | switch_thread t \<Rightarrow> f2 t
                  | choose_new_thread \<Rightarrow> f3)
       (case act' of ResumeCurrentThread \<Rightarrow> g1
                   | ChooseNewThread \<Rightarrow> g3
                   | SwitchToThread t \<Rightarrow> g2 t)"
  apply (cases act)
    apply (rule corres_guard_imp, force+)+
    done

lemma get_sa_corres':
  "corres sched_act_relation P P' (gets scheduler_action) getSchedulerAction"
  by (clarsimp simp: getSchedulerAction_def state_relation_def)

lemma corres_assert_ret:
  "corres dc (\<lambda>s. P) \<top> (assert P) (return ())"
  apply (rule corres_no_failI)
   apply simp
  apply (simp add: assert_def return_def fail_def)
  done

lemma corres_assert_assume_l:
  "corres dc P Q (f ()) g
  \<Longrightarrow> corres dc (P and (\<lambda>s. P')) Q (assert P' >>= f) g"
  by (force simp: corres_underlying_def assert_def return_def bind_def fail_def)

crunch cur[wp]: tcbSchedEnqueue cur_tcb'
  (simp: unless_def)

(* FIXME: move *)
lemma corres_noop3:
  assumes x: "\<And>s s'. \<lbrakk>P s; P' s'; (s, s') \<in> sr\<rbrakk>  \<Longrightarrow> \<lbrace>op = s\<rbrace> f \<exists>\<lbrace>\<lambda>r. op = s\<rbrace>"
  assumes y: "\<And>s s'. \<lbrakk>P s; P' s'; (s, s') \<in> sr\<rbrakk> \<Longrightarrow> \<lbrace>op = s'\<rbrace> g \<lbrace>\<lambda>r. op = s'\<rbrace>"
  assumes z: "nf \<Longrightarrow> no_fail P' g"
  shows      "corres_underlying sr nf dc P P' f g"
  apply (clarsimp simp: corres_underlying_def)
  apply (rule conjI)
   apply clarsimp
   apply (rule use_exs_valid)
    apply (rule exs_hoare_post_imp)
     prefer 2
     apply (rule x)
       apply assumption+
    apply simp_all
   apply (subgoal_tac "ba = b")
    apply simp
   apply (rule sym)
   apply (rule use_valid[OF _ y], assumption+)
   apply simp
  apply (insert z)
  apply (clarsimp simp: no_fail_def)
  done

lemma corres_symb_exec_l':
  assumes z: "\<And>rv. corres_underlying sr nf r (Q' rv) P' (x rv) y"
  assumes x: "\<And>s. P s \<Longrightarrow> \<lbrace>op = s\<rbrace> m \<exists>\<lbrace>\<lambda>r. op = s\<rbrace>"
  assumes y: "\<lbrace>Q\<rbrace> m \<lbrace>Q'\<rbrace>"
  shows      "corres_underlying sr nf r (P and Q) P' (m >>= (\<lambda>rv. x rv)) y"
  apply (rule corres_guard_imp)
    apply (subst gets_bind_ign[symmetric], rule corres_split)
       apply (rule z)
      apply (rule corres_noop3)
        apply (erule x)
       apply (rule gets_wp)
      apply (rule non_fail_gets)
     apply (rule y)
    apply (rule gets_wp)
   apply simp+
   done

lemma corres_symb_exec_r':
  assumes z: "\<And>rv. corres_underlying sr nf r P (P'' rv) x (y rv)"
  assumes y: "\<lbrace>P'\<rbrace> m \<lbrace>P''\<rbrace>"
  assumes x: "\<And>s. Q' s \<Longrightarrow> \<lbrace>op = s\<rbrace> m \<lbrace>\<lambda>r. op = s\<rbrace>"
  assumes nf: "nf \<Longrightarrow> no_fail R' m"
  shows      "corres_underlying sr nf r P (P' and Q' and R') x (m >>= (\<lambda>rv. y rv))"
  apply (rule corres_guard_imp)
    apply (subst gets_bind_ign[symmetric], rule corres_split)
       apply (rule z)
      apply (rule_tac P'="?a' and ?a''" in corres_noop3)
        apply (simp add: simpler_gets_def exs_valid_def)
       apply clarsimp
       apply (erule x)
      apply (rule no_fail_pre)
       apply (erule nf)
      apply clarsimp
      apply assumption
     apply (rule gets_wp)
    apply (rule y)
   apply simp+
  done

lemma corres_case_list:
  "\<lbrakk>list = list'; corres r P P' f1 g1; \<And>x xs. corres r (Q x xs) (Q' x xs) (f2 x xs) (g2 x xs)\<rbrakk>
    \<Longrightarrow> corres r (case list of [] \<Rightarrow> P | x # xs \<Rightarrow> Q x xs)
                (case list' of [] \<Rightarrow> P' | x # xs \<Rightarrow> Q' x xs)
       (case list of [] \<Rightarrow> f1 | x # xs \<Rightarrow> f2 x xs)
       (case list' of [] \<Rightarrow> g1 | x # xs \<Rightarrow> g2 x xs)"
  apply (cases list)
   apply (rule corres_guard_imp, force+)+
   done

lemma findM_corres:
  "\<lbrakk>\<And>x. x \<in> set xs \<Longrightarrow> corres op = P P' (f x) (f' x);
    \<And>x. x \<in> set xs \<Longrightarrow> \<lbrace>P\<rbrace> f x \<lbrace>\<lambda>r. P\<rbrace>; \<And>x. x \<in> set xs \<Longrightarrow> \<lbrace>P'\<rbrace> f' x \<lbrace>\<lambda>r. P'\<rbrace>\<rbrakk>
    \<Longrightarrow> corres op = P P' (findM f xs) (findM f' xs)"
  apply (induct xs)
   apply simp
  apply simp
  apply (rule corres_guard_imp)
    apply (rule corres_split[where r'="op ="])
       apply (rule corres_if[where P=P and P'=P'])
         apply simp
        apply simp
       apply force
      apply force
     apply (atomize, (erule_tac x=a in allE)+, force)+
     done

lemma thread_get_exs_valid[wp]:
  "tcb_at t s \<Longrightarrow> \<lbrace>op = s\<rbrace> thread_get f t \<exists>\<lbrace>\<lambda>r. op = s\<rbrace>"
  apply (clarsimp simp: get_thread_state_def  assert_opt_def fail_def
             thread_get_def gets_the_def exs_valid_def gets_def
             get_def bind_def return_def split: option.splits)
  apply (erule get_tcb_at)
  done

lemma gts_exs_valid[wp]:
  "tcb_at t s \<Longrightarrow> \<lbrace>op = s\<rbrace> get_thread_state t \<exists>\<lbrace>\<lambda>r. op = s\<rbrace>"
  apply (clarsimp simp: get_thread_state_def  assert_opt_def fail_def
             thread_get_def gets_the_def exs_valid_def gets_def
             get_def bind_def return_def split: option.splits)
  apply (erule get_tcb_at)
  done

lemma guarded_switch_to_corres:
  "corres dc (valid_arch_state and valid_objs and valid_asid_map 
                and valid_arch_objs and pspace_aligned and pspace_distinct 
                and valid_vs_lookup and valid_global_objs
                and unique_table_refs o caps_of_state
                and st_tcb_at runnable t and valid_etcbs)
             (valid_arch_state' and valid_pspace' and Invariants_H.valid_queues
                and st_tcb_at' runnable' t and cur_tcb')
             (guarded_switch_to t) (switchToThread t)"
  apply (simp add: guarded_switch_to_def)
  apply (rule corres_guard_imp)
    apply (rule corres_symb_exec_l'[OF _ gts_exs_valid])
      apply (rule corres_assert_assume_l)
      apply (rule switch_thread_corres)
     apply (force simp: st_tcb_at_tcb_at)
    apply (wp gts_st_tcb_at)
    apply (force simp: st_tcb_at_tcb_at)+
    done

 lemma findM_gets_outside: 
   assumes terminate_False: "(\<And>s s' x. (False,s') \<in> fst (g x s) \<Longrightarrow> s = s')"
   shows
   "findM (\<lambda>x. gets (\<lambda>ks. f ks x) >>= g) l = do f' \<leftarrow> gets (\<lambda>ks. f ks); findM (\<lambda>x. (g (f' x))) l od"
   apply (rule ext)
   apply (induct l)
    apply (clarsimp simp add:  bind_def gets_def get_def return_def)
   apply simp
   apply (clarsimp simp add:  bind_def gets_def get_def return_def cong: if_cong split: split_if_asm)
   apply safe
      apply (clarsimp split: split_if_asm)
       apply force
      apply (frule terminate_False)
      apply simp
      apply (rule_tac x="(False,ba)" in bexI,clarsimp+)
     apply (clarsimp split: split_if_asm)+
      apply force
     apply (frule terminate_False)
     apply clarsimp
     apply (rule_tac x="(False,ba)" in bexI,clarsimp+)
    apply (clarsimp split: split_if_asm)+
    apply (frule terminate_False)
    apply clarsimp
    apply force
   apply (clarsimp split: split_if_asm)+
   apply (frule terminate_False)
   apply clarsimp
   apply (rule bexI [rotated], assumption)
   apply auto
   done

lemma corres_gets_queues:
  "corres ready_queues_relation \<top> \<top> (gets ready_queues) (gets ksReadyQueues)"
  apply (simp add: state_relation_def)
  done

definition ready_queues_relation_in_domain ::
     "(Deterministic_A.priority \<Rightarrow> Deterministic_A.ready_queue)
    \<Rightarrow> (priority \<Rightarrow> KernelStateData_H.ready_queue) \<Rightarrow> bool"  where
 "ready_queues_relation_in_domain qs qs' \<equiv> qs = qs'"

lemma corres_gets_queues_blah:
  "corres (ready_queues_relation_in_domain) \<top> \<top> (gets (\<lambda>s. ready_queues s d)) (gets (\<lambda>s p. ksReadyQueues s (d, p)))"
  by (auto simp: state_relation_def ready_queues_relation_def ready_queues_relation_in_domain_def)


lemma Max_lt_set: "\<forall>y\<in>A. Max B < (y::word8) \<Longrightarrow> \<forall>y\<in>A. y \<notin> B"
  apply clarsimp
  apply (drule_tac x=y in bspec,simp)
  apply (case_tac "B = {}")
  apply simp+
  apply blast
  done

abbreviation "enumPrio \<equiv> [0.e.maxPriority]"

lemma enumPrio_word_div:
  fixes v :: "8 word"
  assumes vlt: "unat v \<le> unat maxPriority"
  shows "\<exists>xs ys. enumPrio = xs @ [v] @ ys \<and> (\<forall>x\<in>set xs. x < v) \<and> (\<forall>y\<in>set ys. v < y)"
  apply (subst upto_enum_word)
  apply (subst upt_add_eq_append'[where j="unat v"])
    apply simp
   apply (rule le_SucI)
   apply (rule vlt)
  apply (simp only: upt_conv_Cons vlt[simplified less_Suc_eq_le[symmetric]])
  apply (intro exI conjI)
    apply fastforce
   apply clarsimp
   apply (drule of_nat_mono_maybe[rotated, where 'a="8"])
    apply (fastforce simp: vlt)
   apply simp
  apply (clarsimp simp: Suc_le_eq)
  apply (erule disjE)
   apply (drule of_nat_mono_maybe[rotated, where 'a="8"])
    apply (simp add: maxPriority_def numPriorities_def)
   apply (clarsimp simp: unat_of_nat_eq)
  apply (erule conjE)
  apply (drule_tac Y="unat v" and X="x" in of_nat_mono_maybe[rotated, where 'a="8"])
   apply (simp add: maxPriority_def numPriorities_def)+
  done

lemma rev_enumPrio_word_div:
  "unat v \<le> unat maxPriority \<Longrightarrow> \<exists>xs ys. rev enumPrio = ys @ [(v::word8)] @ xs \<and> (\<forall>x\<in>set xs. x < v) \<and> (\<forall>y\<in>set ys. v < y)"
  apply (cut_tac v=v in enumPrio_word_div)
  apply clarsimp
  apply clarsimp
  apply (rule_tac x="rev xs" in exI)
  apply (rule_tac x="rev ys" in exI)
  apply simp
  done

lemma findM_ignore_head: "\<forall>y\<in> set ys. f y = return False \<Longrightarrow> findM f (ys @ xs) = findM f xs"
  apply (induct ys,simp+)
  done

lemma curDomain_corres: "corres (op =) \<top> \<top> (gets cur_domain) (curDomain)"
  by (simp add: curDomain_def state_relation_def)

lemma valid_queues_non_empty: "\<And>s d p. \<lbrakk> valid_queues s; ksReadyQueues s (d, p) \<noteq> [] \<rbrakk> \<Longrightarrow> unat (Max {prio. ksReadyQueues s (d, prio) \<noteq> []}) \<le> unat maxPriority"
  apply (subst word_le_nat_alt[symmetric])
  apply (subst Max_le_iff)
  apply simp
  apply blast
  apply (clarsimp simp: valid_queues_def)
  apply (drule spec)
  apply (drule_tac x="a" in spec)
  apply fastforce
  done

lemma chooseThread_corres:
  "corres dc (invs and valid_sched) (invs_no_cicd')
     choose_thread chooseThread"
  apply (rule corres_name_pre)
  apply (simp add: choose_thread_def chooseThread_def getQueue_def)
  apply (subst findM_gets_outside)
   apply (clarsimp simp: in_monad split: list.splits)
  apply (simp add: bind_assoc)
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF _ curDomain_corres])
    apply (rule_tac r'= "\<lambda>x x'. x = x' \<and> x = (ready_queues s d) \<and> x' = (\<lambda>prio. ksReadyQueues s' (curdom, prio)) " and P="op = s" and P'="op = s'" in corres_split)
       apply (rule corres_if_lhs)
        apply (simp add: findM_ignore_head[where xs="[]",simplified] when_def)
        apply (rule_tac Q="op = s" and Q'="op = s'" in corres_guard_imp)
          apply (rule corres_guard_imp)
            apply (rule switch_idle_thread_corres,simp+)
       apply clarsimp
       apply (rule_tac Q="op = s" and Q'="op = s'" in corres_guard_imp)
         apply (cut_tac v="Max {prio. ksReadyQueues s' (curdom, prio) \<noteq> []}" in rev_enumPrio_word_div)
         apply (rule valid_queues_non_empty)
         apply (clarsimp simp: all_invs_but_ct_idle_or_in_cur_domain'_def valid_state'_def)
         apply assumption
         apply clarsimp
         apply (drule Max_lt_set,simp)
         apply (subst findM_ignore_head)
          apply clarsimp
         apply (rule Max_prop)
          apply (clarsimp simp: when_def max_non_empty_queue_def split: list.splits)
          apply (rule corres_guard_imp)
            apply (rule guarded_switch_to_corres[simplified dc_def])
           apply (clarsimp simp add:
                           invs_valid_vs_lookup invs_unique_refs
                           invs_def valid_state_def
                           valid_pspace_def)
           apply (clarsimp simp add: valid_sched_def valid_queues_2_def)
           apply (drule_tac x="curdom" in spec)
           apply (drule_tac x="Max {prio. ready_queues sa curdom prio \<noteq> []}" in spec)
           apply (clarsimp simp add: valid_sched_def)
          apply (clarsimp simp: all_invs_but_ct_idle_or_in_cur_domain'_def valid_state'_def valid_queues_def)
          apply (drule_tac x="curdom" in spec)
          apply (drule_tac x="Max {prio. ready_queues s curdom prio \<noteq> []}" in spec)
          apply (clarsimp simp: st_tcb_at'_def obj_at'_def)
         apply fastforce
        apply simp+
      apply (clarsimp simp: state_relation_def ready_queues_relation_in_domain_def)
      apply (fastforce simp: ready_queues_relation_def)
     apply (wp | simp add: curDomain_def)+
  done

lemma thread_get_comm: "do x \<leftarrow> thread_get f p; y \<leftarrow> gets g; k x y od =
           do y \<leftarrow> gets g; x \<leftarrow> thread_get f p; k x y od"
      apply (rule ext)
  apply (clarsimp simp add: gets_the_def assert_opt_def
                   bind_def gets_def get_def return_def
                   thread_get_def
                   fail_def split: option.splits)
 done


lemma schact_bind_inside: "do x \<leftarrow> f; (case act of resume_cur_thread \<Rightarrow> f1 x
                     | switch_thread t \<Rightarrow> f2 t x
                     | choose_new_thread \<Rightarrow> f3 x) od
          = (case act of resume_cur_thread \<Rightarrow> (do x \<leftarrow> f; f1 x od)
                     | switch_thread t \<Rightarrow> (do x \<leftarrow> f; f2 t x od)
                     | choose_new_thread \<Rightarrow> (do x \<leftarrow> f; f3 x od))"
  apply (case_tac act,simp_all)
  done


interpretation tcb_sched_action_extended: is_extended' "tcb_sched_action f a"
  by (unfold_locales)

lemma domain_time_corres:
  "corres (op =) \<top> \<top> (gets domain_time) getDomainTime"
  by (simp add: getDomainTime_def state_relation_def)

lemma next_domain_corres:
  "corres dc \<top> \<top> next_domain nextDomain"
  apply (simp add: next_domain_def nextDomain_def)
  apply (rule corres_modify)
  apply (simp add: state_relation_def Let_def dschLength_def dschDomain_def)
  done

(* FIXME: Move to Invariants_H. *)

interpretation ksCurDomain:
  P_Arch_Idle_Int_update_eq "ksCurDomain_update f"
  by unfold_locales auto

interpretation ksDomScheduleIdx:
  P_Arch_Idle_Int_Cur_update_eq "ksDomScheduleIdx_update f"
  by unfold_locales auto

interpretation ksDomSchedule:
  P_Arch_Idle_Int_Cur_update_eq "ksDomSchedule_update f"
  by unfold_locales auto

interpretation ksDomainTime:
  P_Arch_Idle_Int_Cur_update_eq "ksDomainTime_update f"
  by unfold_locales auto

lemma valid_queues'_ksCurDomain[simp]:
  "valid_queues' (ksCurDomain_update f s) = valid_queues' s"
  by (simp add: valid_queues'_def)

lemma valid_queues'_ksDomScheduleIdx[simp]:
  "valid_queues' (ksDomScheduleIdx_update f s) = valid_queues' s"
  by (simp add: valid_queues'_def)

lemma valid_queues'_ksDomSchedule[simp]:
  "valid_queues' (ksDomSchedule_update f s) = valid_queues' s"
  by (simp add: valid_queues'_def)

lemma valid_queues'_ksDomainTime[simp]:
  "valid_queues' (ksDomainTime_update f s) = valid_queues' s"
  by (simp add: valid_queues'_def)

lemma valid_queues'_ksWorkUnitsCompleted[simp]:
  "valid_queues' (ksWorkUnitsCompleted_update f s) = valid_queues' s"
  by (simp add: valid_queues'_def)

lemma valid_queues_ksCurDomain[simp]:
  "Invariants_H.valid_queues (ksCurDomain_update f s) = Invariants_H.valid_queues s"
  by (simp add: Invariants_H.valid_queues_def)

lemma valid_queues_ksDomScheduleIdx[simp]:
  "Invariants_H.valid_queues (ksDomScheduleIdx_update f s) = Invariants_H.valid_queues s"
  by (simp add: Invariants_H.valid_queues_def)

lemma valid_queues_ksDomSchedule[simp]:
  "Invariants_H.valid_queues (ksDomSchedule_update f s) = Invariants_H.valid_queues s"
  by (simp add: Invariants_H.valid_queues_def)

lemma valid_queues_ksDomainTime[simp]:
  "Invariants_H.valid_queues (ksDomainTime_update f s) = Invariants_H.valid_queues s"
  by (simp add: Invariants_H.valid_queues_def)

lemma valid_queues_ksWorkUnitsCompleted[simp]:
  "Invariants_H.valid_queues (ksWorkUnitsCompleted_update f s) = Invariants_H.valid_queues s"
  by (simp add: Invariants_H.valid_queues_def)

lemma valid_irq_node'_ksCurDomain[simp]:
  "valid_irq_node' w (ksCurDomain_update f s) = valid_irq_node' w s"
  by (simp add: valid_irq_node'_def)

lemma valid_irq_node'_ksDomScheduleIdx[simp]:
  "valid_irq_node' w (ksDomScheduleIdx_update f s) = valid_irq_node' w s"
  by (simp add: valid_irq_node'_def)

lemma valid_irq_node'_ksDomSchedule[simp]:
  "valid_irq_node' w (ksDomSchedule_update f s) = valid_irq_node' w s"
  by (simp add: valid_irq_node'_def)

lemma valid_irq_node'_ksDomainTime[simp]:
  "valid_irq_node' w (ksDomainTime_update f s) = valid_irq_node' w s"
  by (simp add: valid_irq_node'_def)

lemma valid_irq_node'_ksWorkUnitsCompleted[simp]:
  "valid_irq_node' w (ksWorkUnitsCompleted_update f s) = valid_irq_node' w s"
  by (simp add: valid_irq_node'_def)

lemma sch_act_wf_ksCurDomain [simp]:
  "sa = ChooseNewThread \<Longrightarrow> sch_act_wf sa (ksCurDomain_update f s) = sch_act_wf sa s"
  apply (cases sa)
  apply (simp_all add: ct_in_state'_def  tcb_in_cur_domain'_def)
  done

lemma next_domain_valid_sched[wp]:
  "\<lbrace> valid_sched and (\<lambda>s. scheduler_action s  = choose_new_thread)\<rbrace> next_domain \<lbrace> \<lambda>_. valid_sched \<rbrace>"
  apply (simp add: next_domain_def Let_def)
  apply (wp, simp add: valid_sched_def valid_sched_action_2_def ct_not_in_q_2_def)
  apply (simp add:valid_blocked_2_def)
  done

lemma nextDomain_invs_no_cicd':
  "\<lbrace> invs' and (\<lambda>s. ksSchedulerAction s = ChooseNewThread)\<rbrace> nextDomain \<lbrace> \<lambda>_. invs_no_cicd' \<rbrace>"
  apply (simp add: nextDomain_def Let_def dschLength_def dschDomain_def)
  apply wp
  apply (clarsimp simp: invs'_def valid_state'_def valid_machine_state'_def
                        ct_not_inQ_def cur_tcb'_def ct_idle_or_in_cur_domain'_def dschDomain_def all_invs_but_ct_idle_or_in_cur_domain'_def)
  done

lemma schedule_ChooseNewThread_fragment_corres:
  "corres dc (invs and valid_sched and (\<lambda>s. scheduler_action s = choose_new_thread)) (invs' and (\<lambda>s. ksSchedulerAction s = ChooseNewThread))
     (do _ \<leftarrow> when (domainTime = 0) next_domain;
         choose_thread
      od)
     (do _ \<leftarrow> when (domainTime = 0) nextDomain;
          chooseThread
      od)"
  apply (subst bind_dummy_ret_val)
  apply (subst bind_dummy_ret_val)
  apply (rule corres_guard_imp)
  apply (rule corres_split[OF _ corres_when])
  apply (simp add: K_bind_def)
  apply (rule chooseThread_corres)
  apply simp
  apply (rule next_domain_corres)
  apply (wp nextDomain_invs_no_cicd')
  apply (clarsimp simp: valid_sched_def invs'_def valid_state'_def all_invs_but_ct_idle_or_in_cur_domain'_def)+
  done

lemma schedule_corres:
  "corres dc (invs and valid_sched) invs' (Schedule_A.schedule) ThreadDecls_H.schedule"
  apply (clarsimp simp: Schedule_A.schedule_def Thread_H.schedule_def)
  apply (subst thread_get_test)
  apply (subst thread_get_comm)
  apply (subst schact_bind_inside)
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF _ gct_corres[THEN corres_rel_imp[where r="\<lambda>x y. y = x"],simplified, OF TrueI]])
      apply (rule corres_guard_imp)
        apply (rule corres_split[OF _ get_sa_corres'])
          apply (rule corres_split_sched_act,assumption)
            apply (rule_tac P="tcb_at cur" in corres_symb_exec_l')
              apply (rule_tac corres_symb_exec_l')
                apply simp
                apply (rule corres_assert_ret)
               apply (wp gets_exs_valid | simp)+
            apply (rule thread_get_wp')
           apply simp
           apply (rule corres_split[OF _ thread_get_isRunnable_corres])
             apply (rule corres_split[OF _ corres_when])
                 apply (rule corres_split[OF _ guarded_switch_to_corres])
                   apply (rule set_sa_corres)
                   apply (wp | simp)+
               apply (rule tcbSchedEnqueue_corres)
              apply (wp thread_get_wp' | simp)+
          apply (rule corres_split[OF _ thread_get_isRunnable_corres])
            apply (rule corres_split[OF _ corres_when])
                apply (rule corres_split[OF _ domain_time_corres], clarsimp, fold dc_def)
                 apply (rule corres_split[OF _ schedule_ChooseNewThread_fragment_corres, simplified bind_assoc])
                  apply (rule set_sa_corres)
                  apply (wp | simp)+
                 apply (wp | simp add: getDomainTime_def)+
              apply (rule tcbSchedEnqueue_corres, simp)
             apply (simp_all only: cong: if_cong Deterministic_A.scheduler_action.case_cong
                                           Structures_H.scheduler_action.case_cong)
           apply ((wp thread_get_wp' hoare_vcg_conj_lift hoare_drop_imps | clarsimp)+)
   apply (rule conjI,simp)
   apply (clarsimp split:Deterministic_A.scheduler_action.splits
     simp: invs_psp_aligned invs_distinct invs_valid_objs
     invs_arch_state invs_arch_objs)
   apply (intro impI conjI allI tcb_at_invs | (fastforce
          simp: invs_def cur_tcb_def valid_arch_caps_def
                valid_sched_def valid_sched_action_def
               is_activatable_def st_tcb_at_def obj_at_def
                valid_state_def only_idle_def valid_etcbs_def
                weak_valid_sched_action_def
                not_cur_thread_def tcb_at_invs
          ))+
    apply (cut_tac s = s in valid_blocked_valid_blocked_except)
     prefer 2
     apply (simp add:valid_sched_def)
    apply (simp add:valid_sched_def)
   apply simp
  apply (fastforce simp: invs'_def cur_tcb'_def valid_state'_def st_tcb_at'_def
                         sch_act_wf_def  valid_pspace'_def valid_objs'_maxDomain
                         valid_objs'_maxPriority comp_def
                   split: scheduler_action.splits)
  done

lemma ssa_all_invs_but_ct_not_inQ':
  "\<lbrace>all_invs_but_ct_not_inQ' and sch_act_wf sa and 
   (\<lambda>s. sa = ResumeCurrentThread \<longrightarrow> ksCurThread s = ksIdleThread s \<or> tcb_in_cur_domain' (ksCurThread s) s)\<rbrace>
   setSchedulerAction sa \<lbrace>\<lambda>rv. all_invs_but_ct_not_inQ'\<rbrace>"
proof -
  have obj_at'_sa: "\<And>P addr f s.
       obj_at' P addr (ksSchedulerAction_update f s) = obj_at' P addr s"
    by (fastforce intro: obj_at'_pspaceI)
  have valid_pspace'_sa: "\<And>f s.
       valid_pspace' (ksSchedulerAction_update f s) = valid_pspace' s"
    by (rule valid_pspace'_ksPSpace, simp)
  have iflive_sa: "\<And>f s.
       if_live_then_nonz_cap' (ksSchedulerAction_update f s)
         = if_live_then_nonz_cap' s"
    by (fastforce intro: if_live_then_nonz_cap'_pspaceI)
  have ifunsafe_sa[simp]: "\<And>f s.
       if_unsafe_then_cap' (ksSchedulerAction_update f s) = if_unsafe_then_cap' s"
    by fastforce
  have idle_sa[simp]: "\<And>f s.
       valid_idle' (ksSchedulerAction_update f s) = valid_idle' s"
    by fastforce
  show ?thesis
    apply (simp add: setSchedulerAction_def)
    apply wp
    apply (clarsimp simp add: invs'_def valid_state'_def cur_tcb'_def
                              obj_at'_sa valid_pspace'_sa Invariants_H.valid_queues_def
                              state_refs_of'_def iflive_sa ps_clear_def
                              valid_irq_node'_def valid_queues'_def
                              tcb_in_cur_domain'_def ct_idle_or_in_cur_domain'_def
                        cong: option.case_cong)
    done
qed

lemma ssa_ct_not_inQ:
  "\<lbrace>\<lambda>s. sa = ResumeCurrentThread \<longrightarrow> obj_at' (Not \<circ> tcbQueued) (ksCurThread s) s\<rbrace>
   setSchedulerAction sa \<lbrace>\<lambda>rv. ct_not_inQ\<rbrace>"
  by (simp add: setSchedulerAction_def ct_not_inQ_def, wp, clarsimp)

thm ct_idle_or_in_cur_domain'_def

lemma ssa_all_invs_but_ct_not_inQ''[simplified]:
  "\<lbrace>\<lambda>s. (all_invs_but_ct_not_inQ' s \<and> sch_act_wf sa s) 
    \<and> (sa = ResumeCurrentThread \<longrightarrow> ksCurThread s = ksIdleThread s \<or> tcb_in_cur_domain' (ksCurThread s) s)
    \<and> (sa = ResumeCurrentThread \<longrightarrow> obj_at' (Not \<circ> tcbQueued) (ksCurThread s) s)\<rbrace>
   setSchedulerAction sa \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp only: all_invs_but_not_ct_inQ_check' [symmetric])
  apply (rule hoare_elim_pred_conj)
  apply (wp hoare_vcg_conj_lift [OF ssa_all_invs_but_ct_not_inQ' ssa_ct_not_inQ])
  apply (clarsimp)
  done

lemma ssa_invs':
  "\<lbrace>invs' and sch_act_wf sa and
    (\<lambda>s. sa = ResumeCurrentThread \<longrightarrow> ksCurThread s = ksIdleThread s \<or> tcb_in_cur_domain' (ksCurThread s) s) and
    (\<lambda>s. sa = ResumeCurrentThread \<longrightarrow> obj_at' (Not \<circ> tcbQueued) (ksCurThread s) s)\<rbrace>
   setSchedulerAction sa \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (wp ssa_all_invs_but_ct_not_inQ'')
  apply (clarsimp simp add: invs'_def valid_state'_def)
  done

lemma getDomainTime_wp[wp]: "\<lbrace>\<lambda>s. P (ksDomainTime s) s \<rbrace> getDomainTime \<lbrace> P \<rbrace>"
  unfolding getDomainTime_def
  by wp

(******************************************************************************************************************************************)

lemma setCurThread_invs_no_cicd':
  "\<lbrace>invs_no_cicd' and st_tcb_at' activatable' t and obj_at' (\<lambda>x. \<not> tcbQueued x) t and tcb_in_cur_domain' t\<rbrace>
     setCurThread t
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
proof -
  have obj_at'_ct: "\<And>f P addr s.
       obj_at' P addr (ksCurThread_update f s) = obj_at' P addr s"
    by (fastforce intro: obj_at'_pspaceI)
  have valid_pspace'_ct: "\<And>s f.
       valid_pspace' (ksCurThread_update f s) = valid_pspace' s"
    by (rule valid_pspace'_ksPSpace, simp)
  have vms'_ct: "\<And>s f.
       valid_machine_state' (ksCurThread_update f s) = valid_machine_state' s"
    by (simp add: valid_machine_state'_def)
  have ct_not_inQ_ct: "\<And>s t . \<lbrakk> ct_not_inQ s; obj_at' (\<lambda>x. \<not> tcbQueued x) t s\<rbrakk> \<Longrightarrow> ct_not_inQ (s\<lparr> ksCurThread := t \<rparr>)"
    apply (simp add: ct_not_inQ_def o_def)
    done
  have tcb_in_cur_domain_ct: "\<And>s f t.
       tcb_in_cur_domain' t  (ksCurThread_update f s)= tcb_in_cur_domain' t s"
    by (fastforce simp: tcb_in_cur_domain'_def)
  show ?thesis
    apply (simp add: setCurThread_def)
    apply wp
    apply (clarsimp simp add: all_invs_but_ct_idle_or_in_cur_domain'_def invs'_def cur_tcb'_def valid_state'_def obj_at'_ct
                              valid_pspace'_ct vms'_ct Invariants_H.valid_queues_def
                              sch_act_wf ct_in_state'_def state_refs_of'_def
                              ps_clear_def valid_irq_node'_def valid_queues'_def ct_not_inQ_ct
                              tcb_in_cur_domain_ct ct_idle_or_in_cur_domain'_def
                        cong: option.case_cong)
    done
qed

lemma clearExMonitor_invs_no_cicd'[wp]:
  "\<lbrace>invs_no_cicd'\<rbrace> doMachineOp MachineOps.clearExMonitor \<lbrace>\<lambda>rv. invs_no_cicd'\<rbrace>"
  apply (wp dmo_invs_no_cicd')
   apply (simp add: no_irq_clearExMonitor)
  apply (clarsimp simp: MachineOps.clearExMonitor_def machine_op_lift_def
                        in_monad select_f_def)
  done

lemma Arch_switchToThread_invs_no_cicd':
  "\<lbrace>invs_no_cicd'\<rbrace> ArchThreadDecls_H.switchToThread t \<lbrace>\<lambda>rv. invs_no_cicd'\<rbrace>"
  apply (simp add: ArchThread_H.switchToThread_def)
  apply (wp setVMRoot_invs_no_cicd')
  done

lemma tcbSchedDequeue_invs_no_cicd'[wp]:
  "\<lbrace>invs_no_cicd' and tcb_at' t\<rbrace>
     tcbSchedDequeue t
   \<lbrace>\<lambda>_. invs_no_cicd'\<rbrace>"
  apply (simp add: all_invs_but_ct_idle_or_in_cur_domain'_def valid_state'_def )
  apply (wp tcbSchedDequeue_ct_not_inQ sch_act_wf_lift valid_irq_node_lift irqs_masked_lift
            valid_irq_handlers_lift' cur_tcb_lift ct_idle_or_in_cur_domain'_lift2
       | simp add: cteCaps_of_def )+
  apply (fastforce elim: valid_objs'_maxDomain valid_objs'_maxPriority simp: valid_pspace'_def)+
  done

lemma switchToThread_invs_no_cicd':
  "\<lbrace>invs_no_cicd' and st_tcb_at' runnable' t and tcb_in_cur_domain' t \<rbrace> ThreadDecls_H.switchToThread t \<lbrace>\<lambda>rv. invs' \<rbrace>"
  apply (simp add: switchToThread_def )
  apply (wp setCurThread_invs_no_cicd'
             Arch_switchToThread_invs_no_cicd' Arch_switchToThread_st_tcb'
              tcbSchedDequeue_not_tcbQueued)
  apply (clarsimp elim!: st_tcb'_weakenE)+
  done

lemma chooseThread_invs_no_cicd'_fragment: "\<lbrace>invs_no_cicd' and (\<lambda>s. ksCurDomain s = d)\<rbrace>
      findM (\<lambda>prio. getQueue d prio >>= case_list (return False) (\<lambda>thread x. do y \<leftarrow> ThreadDecls_H.switchToThread thread;
                                                                                           return True
                                                                                         od))
      (rev enumPrio)
       \<lbrace>\<lambda>r. if r = None then invs_no_cicd' else invs'\<rbrace>"
  apply (rule hoare_weaken_pre)
   apply (rule findM_on_outcome)
   apply clarsimp
   apply (rule seq_ext)
    apply (rule_tac P="invs_no_cicd' and (\<lambda>s. ksCurDomain s = d)" in gq_sp)
   apply (case_tac "xa")
    apply (simp)
    apply (wp)
    apply (clarsimp)
   apply (simp)
   apply wp
   apply clarsimp
  apply (rule hoare_weaken_pre)
  apply (rule switchToThread_invs_no_cicd')
  apply (clarsimp simp: invs'_def all_invs_but_ct_idle_or_in_cur_domain'_def valid_state'_def, rule conjI)
   apply (rule valid_queues_running)
    apply (rule suffixeq_Cons_mem)
    apply (simp add: suffixeq_def)
    apply (rule exI)
    apply (rule eq_Nil_appendI)
    apply simp+
  apply (simp add: tcb_in_cur_domain'_def valid_queues_def)
  apply (drule_tac x="ksCurDomain s" in spec)
  apply (drule_tac x=x in spec)
  apply (fastforce simp: obj_at'_def inQ_def)
  apply clarsimp
  done

lemma setCurThread_invs_no_cicd'_idle_thread:
  "\<lbrace>invs_no_cicd' and (\<lambda>s. t = ksIdleThread s) and tcb_at' t \<rbrace> setCurThread t \<lbrace>\<lambda>rv. invs'\<rbrace>"
proof -
  have vms'_ct: "\<And>s f.
       valid_machine_state' (ksCurThread_update f s) = valid_machine_state' s"
    by (simp add: valid_machine_state'_def)
  have ct_not_inQ_ct: "\<And>s t . \<lbrakk> ct_not_inQ s; obj_at' (\<lambda>x. \<not> tcbQueued x) t s\<rbrakk> \<Longrightarrow> ct_not_inQ (s\<lparr> ksCurThread := t \<rparr>)"
    apply (simp add: ct_not_inQ_def o_def)
    done
  have idle'_activatable': "\<And> s t. st_tcb_at' idle' t s \<Longrightarrow> st_tcb_at' activatable' t s"
    apply (clarsimp simp: st_tcb_at'_def o_def obj_at'_def)
  done
  show ?thesis
    apply (simp add: setCurThread_def)
    apply wp
    apply (clarsimp simp add: vms'_ct ct_not_inQ_ct idle'_activatable' idle'_not_tcbQueued'[simplified o_def]
                              all_invs_but_ct_idle_or_in_cur_domain'_def invs'_def cur_tcb'_def valid_state'_def valid_idle'_def
                              sch_act_wf ct_in_state'_def state_refs_of'_def
                              ps_clear_def valid_irq_node'_def
                               ct_idle_or_in_cur_domain'_def tcb_in_cur_domain'_def
                        cong: option.case_cong)
    done
qed

lemma switchToIdleThread_invs_no_cicd':
  "\<lbrace>invs_no_cicd'\<rbrace> switchToIdleThread \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (clarsimp simp: switchToIdleThread_def ArchThread_H.switchToIdleThread_def)
  apply (wp_trace setCurThread_invs_no_cicd'_idle_thread storeWordUser_invs_no_cicd')
  apply (clarsimp simp: all_invs_but_ct_idle_or_in_cur_domain'_def valid_idle'_def)
  done

lemma chooseThread_invs_no_cicd':
  "\<lbrace> invs_no_cicd' \<rbrace> chooseThread \<lbrace> \<lambda>_. invs' \<rbrace>"
  apply (simp add: chooseThread_def Let_def curDomain_def cong: if_cong)
  apply (rule hoare_seq_ext [OF _ gets_sp])
  apply (wp switchToIdleThread_invs_no_cicd')
  apply (wp chooseThread_invs_no_cicd'_fragment)
  done

lemma switchToThread_ct_not_queued_2:
  "\<lbrace>invs_no_cicd' and tcb_at' t\<rbrace> switchToThread t \<lbrace>\<lambda>rv s. obj_at' (Not \<circ> tcbQueued) (ksCurThread s) s\<rbrace>"
  (is "\<lbrace>_\<rbrace> _ \<lbrace>\<lambda>_. ?POST\<rbrace>")
  apply (simp add: switchToThread_def)
  apply (wp)
    apply (simp add: switchToThread_def setCurThread_def)
    apply (wp tcbSchedDequeue_not_tcbQueued | simp )+
  done

lemma hd_ksReadyQueues_runnable_2:
  "\<lbrakk>Invariants_H.valid_queues s; ksReadyQueues s (d, p) = a # as\<rbrakk>
     \<Longrightarrow> st_tcb_at' runnable' a s"
   apply( rule valid_queues_running)
   apply(rule suffixeq_Cons_mem)
   apply(simp add: suffixeq_def)
   apply(rule exI)
   apply(rule eq_Nil_appendI)
   by auto

lemma chooseThread_ct_not_queued_2:
  "\<lbrace> invs_no_cicd'\<rbrace> chooseThread \<lbrace>\<lambda>rv s. obj_at' (Not \<circ> tcbQueued) (ksCurThread s) s\<rbrace>"
  (is "\<lbrace>_\<rbrace> _ \<lbrace>\<lambda>_. ?POST\<rbrace>")
  apply (simp add: chooseThread_def curDomain_def all_invs_but_ct_idle_or_in_cur_domain'_def)
  apply (rule hoare_seq_ext [OF _ gets_sp])
  apply (wp)
   apply (rule_tac Q="\<lambda>_ s. ksCurThread s = ksIdleThread s
                            \<and> obj_at' (Not \<circ> tcbQueued) (ksIdleThread s) s"
            in hoare_post_imp, clarsimp)
   apply (wp switchToIdleThread_curr_is_idle)
   apply (wps switchToIdleThread_it)
   apply (simp add: switchToIdleThread_def
                    ArchThread_H.switchToIdleThread_def)
   apply (wp)
   apply (rule hoare_weaken_pre)
   apply (rule_tac I="invs_no_cicd' and (\<lambda>s. ksCurDomain s = curdom)" in  findM_on_outcome)
   apply (clarsimp)
   apply (wp | wpc | clarsimp)+
    apply (wp switchToThread_ct_not_queued_2)
   apply (clarsimp simp: all_invs_but_ct_idle_or_in_cur_domain'_def)
   apply (frule(1) hd_ksReadyQueues_runnable_2)
   apply (clarsimp simp: invs'_def valid_state'_def all_invs_but_ct_idle_or_in_cur_domain'_def)+
  apply (erule(2) idle'_not_tcbQueued')
  done

lemma switchToIdleThread_activatable_2[wp]:
  "\<lbrace>invs_no_cicd'\<rbrace> switchToIdleThread \<lbrace>\<lambda>rv. ct_in_state' activatable'\<rbrace>"
  apply (simp add: switchToIdleThread_def
                   ArchThread_H.switchToIdleThread_def)
  apply (wp setCurThread_ct_in_state)
  apply (clarsimp simp: all_invs_but_ct_idle_or_in_cur_domain'_def valid_state'_def valid_idle'_def
                        st_tcb_at'_def obj_at'_def)
  done

lemma chooseThread_activatable_2:
  "\<lbrace>invs_no_cicd'\<rbrace> chooseThread \<lbrace>\<lambda>rv. ct_in_state' activatable'\<rbrace>"
  apply (simp add: chooseThread_def Let_def cong: if_cong)
  apply (wp)
  apply (rule hoare_weaken_pre)
  apply (rule findM_on_outcome [where I="invs_no_cicd'"])
   apply (rename_tac prio ys)
   apply(clarsimp)
   apply (wp, wpc, wp)
    apply (clarsimp)
    apply (wp switchToThread_ct_in_state)
   apply (clarsimp simp: all_invs_but_ct_idle_or_in_cur_domain'_def)
   apply (drule(1) hd_ksReadyQueues_runnable_2)
   apply (simp only: st_tcb_at'_def)
   apply (erule obj_at'_weakenE)
   apply (simp add: curDomain_def)+
  done

lemma switchToThread_tcb_in_cur_domain':
  "\<lbrace>tcb_in_cur_domain' thread\<rbrace> ThreadDecls_H.switchToThread thread 
  \<lbrace>\<lambda>y s. tcb_in_cur_domain' (ksCurThread s) s\<rbrace>"
  apply (simp add: switchToThread_def)
  apply (rule hoare_pre)
  apply (wp)
    apply (simp add: switchToThread_def setCurThread_def)
    apply (wp tcbSchedDequeue_not_tcbQueued | simp )+
   apply (simp add:tcb_in_cur_domain'_def)
   apply (wp tcbSchedDequeue_tcbDomain | wps)+
  apply (clarsimp simp:tcb_in_cur_domain'_def)
  done
  
lemma chooseThread_in_cur_domain': 
  "\<lbrace>valid_queues\<rbrace> chooseThread \<lbrace>\<lambda>rv s. ksCurThread s = ksIdleThread s \<or> tcb_in_cur_domain' (ksCurThread s) s\<rbrace>"
  apply (simp add:chooseThread_def)
   apply wp
    apply (rule hoare_strengthen_post[OF switchToIdleThread_curr_is_idle])
    apply simp
   apply (rule_tac I="valid_queues and (\<lambda>s. ksCurDomain s = curdom)" in  findM_on_outcome)
   apply (wp |wpc|simp)+
    apply (rule hoare_strengthen_post[OF switchToThread_tcb_in_cur_domain'])
    apply simp
   apply clarsimp
   apply wp
   apply clarsimp
   apply (drule_tac t = xa and d = "ksCurDomain s"
     and p = x in ready_tcb_valid_queues[rotated])
    apply fastforce
   apply (clarsimp simp add:inQ_def obj_at'_def
     tcb_in_cur_domain'_def)
  apply (simp add:curDomain_def | wp)+
  done

lemma schedule_ChooseNewThread_fragment_invs':
  "\<lbrace> invs' and (\<lambda>s. ksSchedulerAction s = ChooseNewThread) \<rbrace>
     do _ \<leftarrow> when (domainTime = 0) nextDomain;
            chooseThread od
   \<lbrace> \<lambda>_ s. invs' s \<and> ct_in_state' activatable' s \<and> 
    obj_at' (Not \<circ> tcbQueued) (ksCurThread s) s \<and>
    (ksCurThread s = ksIdleThread s \<or> tcb_in_cur_domain' (ksCurThread s) s) \<rbrace>"
  apply (rule hoare_seq_ext)
  apply (wp chooseThread_ct_not_queued_2 chooseThread_activatable_2 chooseThread_invs_no_cicd')
  apply (wp chooseThread_in_cur_domain' nextDomain_invs_no_cicd')
   apply (simp add:nextDomain_def)
   apply wp
  apply (clarsimp simp: invs'_def all_invs_but_ct_idle_or_in_cur_domain'_def Let_def valid_state'_def)
  done

(****************************************************************************************************************************)

lemma schedule_invs': "\<lbrace>invs'\<rbrace> ThreadDecls_H.schedule \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp add: schedule_def)
  apply (rule_tac hoare_seq_ext, rename_tac t)
   apply (wp, wpc)
      -- "action = ResumeCurrentThread"
      apply (wp)[1]
     -- "action = ChooseNewThread"
     apply (rule_tac hoare_seq_ext, rename_tac r)
      apply (rule hoare_seq_ext, simp add: K_bind_def)
      apply (rule hoare_seq_ext)
      apply (rule seq_ext[OF schedule_ChooseNewThread_fragment_invs' _, simplified bind_assoc])
      apply (wp ssa_invs' chooseThread_invs_no_cicd')
       apply clarsimp
       apply (wp)[3]
    -- "action = SwitchToThread"
    apply (rule_tac hoare_seq_ext, rename_tac r)
     apply (wp ssa_invs')
      apply (clarsimp)
      apply wp
      apply (rule_tac Q="\<lambda>_. (\<lambda>s. tcb_in_cur_domain' (ksCurThread s) s)
              and (\<lambda>s. obj_at' (Not \<circ> tcbQueued) (ksCurThread s) s)"
              in hoare_post_imp)
       apply simp
      apply (wp switchToThread_tcb_in_cur_domain' switchToThread_ct_not_queued)
     apply (rule_tac Q="\<lambda>_. (\<lambda>s. st_tcb_at' activatable' word s) and invs'
              and (\<lambda>s. tcb_in_cur_domain' word s)"
              in hoare_post_imp)
      apply (clarsimp simp:st_tcb_at'_def valid_state'_def obj_at'_def)
     apply (wp)
  apply (frule invs_sch_act_wf')
  apply (auto elim!: obj_at'_weakenE simp: st_tcb_at'_def )
  done

lemma setCurThread_nosch:
  "\<lbrace>\<lambda>s. P (ksSchedulerAction s)\<rbrace>
  setCurThread t
  \<lbrace>\<lambda>rv s. P (ksSchedulerAction s)\<rbrace>"
  apply (simp add: setCurThread_def)
  apply wp
  apply simp
  done

lemma stt_nosch:
  "\<lbrace>\<lambda>s. P (ksSchedulerAction s)\<rbrace>
  switchToThread t
  \<lbrace>\<lambda>rv s. P (ksSchedulerAction s)\<rbrace>"
  apply (simp add: switchToThread_def ArchThread_H.switchToThread_def storeWordUser_def)
  apply (wp setCurThread_nosch hoare_drop_imp |simp)+
  done

lemma stit_nosch[wp]:
  "\<lbrace>\<lambda>s. P (ksSchedulerAction s)\<rbrace>
    switchToIdleThread
   \<lbrace>\<lambda>rv s. P (ksSchedulerAction s)\<rbrace>"
  apply (simp add: switchToIdleThread_def
                   ArchThread_H.switchToIdleThread_def  storeWordUser_def)
  apply (wp setCurThread_nosch | simp add: getIdleThread_def)+
  done

lemma chooseThread_nosch:
  "\<lbrace>\<lambda>s. P (ksSchedulerAction s)\<rbrace>
  chooseThread
  \<lbrace>\<lambda>rv s. P (ksSchedulerAction s)\<rbrace>"
  apply (simp add: chooseThread_def Let_def)
  apply (wp findM_inv | simp)+
  apply (case_tac xa)
  apply (wp stt_nosch | simp add: curDomain_def)+
  done

lemma schedule_sch:
  "\<lbrace>\<top>\<rbrace> schedule \<lbrace>\<lambda>rv s. ksSchedulerAction s = ResumeCurrentThread\<rbrace>"
  by (wp setSchedulerAction_direct | wpc| simp add: schedule_def)+

lemma schedule_sch_act_simple:
  "\<lbrace>\<top>\<rbrace> schedule \<lbrace>\<lambda>rv. sch_act_simple\<rbrace>"
  apply (rule hoare_strengthen_post [OF schedule_sch])
  apply (simp add: sch_act_simple_def)
  done

lemma ssa_ct:
  "\<lbrace>ct_in_state' P\<rbrace> setSchedulerAction sa \<lbrace>\<lambda>rv. ct_in_state' P\<rbrace>"
proof -
  have obj_at'_sa: "\<And>P addr f s.
       obj_at' P addr (ksSchedulerAction_update f s) = obj_at' P addr s"
    by (fastforce intro: obj_at'_pspaceI)
  show ?thesis
    apply (unfold setSchedulerAction_def)
    apply wp
    apply (clarsimp simp add: ct_in_state'_def st_tcb_at'_def obj_at'_sa)
    done
qed


lemma schedule_ct_activatable'[wp]: "\<lbrace>invs'\<rbrace> ThreadDecls_H.schedule \<lbrace>\<lambda>_. ct_in_state' activatable'\<rbrace>"
  apply (simp add: schedule_def)
  apply (rule_tac hoare_seq_ext, rename_tac t)
   apply (wp, wpc)
      -- "action = ResumeCurrentThread"
      apply (wp)[1]
     -- "action = ChooseNewThread"
     apply (rule_tac hoare_seq_ext, rename_tac r)
      apply (rule hoare_seq_ext, simp add: K_bind_def)
      apply (rule hoare_seq_ext)
      apply (rule seq_ext[OF schedule_ChooseNewThread_fragment_invs' _, simplified bind_assoc])
      apply (wp ssa_invs')
       apply (clarsimp simp: ct_in_state'_def, simp)
       apply (wp)[3]
    -- "action = SwitchToThread"
    apply (rule_tac hoare_seq_ext, rename_tac r)
     apply (wp ssa_invs')
       apply (clarsimp simp: ct_in_state'_def, simp)
      apply (wp switchToThread_ct_not_queued sts_ct_in_state_neq')
     apply (rule_tac Q="\<lambda>_. st_tcb_at' activatable' word and invs'"
              in hoare_post_imp)
      apply (fastforce simp: st_tcb_at'_def elim!: obj_at'_weakenE)
     apply (clarsimp simp: )
     apply (wp)
  apply (frule invs_sch_act_wf')
  apply (auto elim!: obj_at'_weakenE simp: st_tcb_at'_def )
  done

lemma threadSet_sch_act_sane:
  "\<lbrace>sch_act_sane\<rbrace> threadSet f t \<lbrace>\<lambda>_. sch_act_sane\<rbrace>"
  by (wp sch_act_sane_lift)

lemma rescheduleRequired_sch_act_sane[wp]:
  "\<lbrace>\<top>\<rbrace> rescheduleRequired \<lbrace>\<lambda>rv. sch_act_sane\<rbrace>"
  apply (simp add: rescheduleRequired_def sch_act_sane_def
                   setSchedulerAction_def)
  by (wp | wpc | clarsimp)+

lemma tcbSchedDequeue_sch_act_sane[wp]:
  "\<lbrace>sch_act_sane\<rbrace> tcbSchedDequeue t \<lbrace>\<lambda>_. sch_act_sane\<rbrace>"
  by (wp sch_act_sane_lift)

lemma sts_sch_act_sane:
  "\<lbrace>sch_act_sane\<rbrace> setThreadState st t \<lbrace>\<lambda>_. sch_act_sane\<rbrace>"
  apply (simp add: setThreadState_def)
  apply (wp hoare_drop_imps
           | simp add: threadSet_sch_act_sane sane_update)+
  done

lemma possibleSwitchTo_corres:
  "corres dc (valid_etcbs and weak_valid_sched_action and cur_tcb and st_tcb_at runnable t)
    (Invariants_H.valid_queues and valid_queues' and
    (\<lambda>s. weak_sch_act_wf (ksSchedulerAction s) s) and cur_tcb' and tcb_at' t and st_tcb_at' runnable' t and valid_objs')
      (possible_switch_to t b)
      (possibleSwitchTo t b)"
  apply (simp add: possible_switch_to_def
                   possibleSwitchTo_def cong: if_cong)
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF _ gct_corres])
      apply simp
      apply (rule corres_split[OF _ curDomain_corres])
      apply (rule corres_split[OF _ ethreadget_corres[where r="op ="]])
         apply (rule corres_split[OF _ ethreadget_corres[where r="op ="]])
          apply (rule corres_split[OF _ ethreadget_corres[where r="op ="]])
            apply (rule corres_split[OF _ get_sa_corres])
              apply (rule corres_if)
               apply (simp+)[2]
             apply (rule tcbSchedEnqueue_corres)
              apply (rule corres_split[where r'=dc])
                 apply (case_tac action,simp_all)[1]
                 apply (rule rescheduleRequired_corres)
                apply (rule corres_if)
                  apply (case_tac action,simp_all)[1]
                 apply (rule set_sa_corres)
                 apply simp
                apply (rule tcbSchedEnqueue_corres)
               apply (wp add: set_scheduler_action_wp del: ssa_lift | simp)+
               apply (rule_tac Q="\<lambda>r. st_tcb_at' runnable' t and tcb_in_cur_domain' t" in valid_prove_more)
               apply (rule ssa_lift)
               apply (clarsimp simp: valid_queues'_def weak_sch_act_wf_def Invariants_H.valid_queues_def
                                     tcb_in_cur_domain'_def st_tcb_at'_def)
              apply (wp threadGet_wp | simp add: etcb_relation_def curDomain_def)+
   apply (clarsimp simp: is_etcb_at_def valid_sched_action_def weak_valid_sched_action_def)
   apply (clarsimp simp: valid_sched_def etcb_at_def cur_tcb_def split: option.splits)
   apply (frule st_tcb_at_tcb_at)
   apply (frule(1) tcb_at_ekheap_dom[where x=t])
   apply clarsimp
   apply (frule_tac x="cur_thread s" in tcb_at_ekheap_dom, simp)
   apply (clarsimp simp: is_etcb_at_def valid_sched_action_def weak_valid_sched_action_def)
  apply (clarsimp simp: cur_tcb'_def)
  apply (frule (1) valid_objs'_maxDomain)
  apply (frule (1) valid_objs'_maxDomain) back
  apply (frule (1) valid_objs'_maxPriority)
  apply (frule (1) valid_objs'_maxPriority) back
  apply (clarsimp simp: cur_tcb'_def obj_at'_def projectKOs objBits_simps)
  apply (rule_tac x=obje in exI)
  apply (auto simp: tcb_in_cur_domain'_def obj_at'_def projectKOs objBits_simps)
  done

lemma attemptSwitchTo_corres:
  "corres dc (valid_etcbs and weak_valid_sched_action and cur_tcb and st_tcb_at runnable t)
    (Invariants_H.valid_queues and valid_queues' and
    (\<lambda>s. weak_sch_act_wf (ksSchedulerAction s) s) and cur_tcb' and tcb_at' t and st_tcb_at' runnable' t and valid_objs')
     (attempt_switch_to t) (attemptSwitchTo t)"
using possibleSwitchTo_corres
apply (simp add: attempt_switch_to_def attemptSwitchTo_def)
done

lemma switchIfRequiredTo_corres:
  "corres dc (valid_etcbs and weak_valid_sched_action and cur_tcb and st_tcb_at runnable t)
    (Invariants_H.valid_queues and valid_queues' and
    (\<lambda>s. weak_sch_act_wf (ksSchedulerAction s) s) and cur_tcb' and tcb_at' t and st_tcb_at' runnable' t and valid_objs')
     (switch_if_required_to t) (switchIfRequiredTo t)"
using possibleSwitchTo_corres
apply (simp add: switch_if_required_to_def switchIfRequiredTo_def)
done

end
