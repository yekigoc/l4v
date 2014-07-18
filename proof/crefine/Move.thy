(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

(* things that should be moved into first refinement *)

theory Move
imports "../refine/Refine"
begin

lemma finaliseCap_Reply:
  "\<lbrace>Q (NullCap,None) and K (isReplyCap cap)\<rbrace> finaliseCapTrue_standin cap fin \<lbrace>Q\<rbrace>"   
  apply (rule NonDetMonadVCG.hoare_gen_asm)
  apply (clarsimp simp: finaliseCapTrue_standin_def isCap_simps)
  apply wp
  done

lemma cteDeleteOne_Reply:
  "\<lbrace>st_tcb_at' P t and cte_wp_at' (isReplyCap o cteCap) slot\<rbrace> cteDeleteOne slot \<lbrace>\<lambda>_. st_tcb_at' P t\<rbrace>"
  apply (simp add: cteDeleteOne_def unless_def split_def)
  apply (wp finaliseCap_Reply isFinalCapability_inv getCTE_wp')
  apply (clarsimp simp: cte_wp_at_ctes_of)
  done

lemma asyncIPCCancel_st_tcb':
  "\<lbrace>\<lambda>s. t\<noteq>t' \<and> st_tcb_at' P t' s\<rbrace> asyncIPCCancel t aep \<lbrace>\<lambda>_. st_tcb_at' P t'\<rbrace>"
  apply (simp add: asyncIPCCancel_def Let_def)
  apply (rule hoare_pre)
   apply (wp sts_st_tcb_neq' getAsyncEP_wp|wpc)+
  apply clarsimp
  done

lemma ipcCancel_st_tcb_at':
  "\<lbrace>\<lambda>s. t\<noteq>t' \<and> st_tcb_at' P t' s\<rbrace> ipcCancel t \<lbrace>\<lambda>_. st_tcb_at' P t'\<rbrace>"
  apply (simp add: ipcCancel_def Let_def getThreadReplySlot_def locateSlot_def)
  apply (rule hoare_pre)
   apply (wp sts_st_tcb_neq' getEndpoint_wp cteDeleteOne_Reply getCTE_wp'|wpc)+
          apply (rule hoare_strengthen_post [where Q="\<lambda>_. st_tcb_at' P t'"])
           apply (wp threadSet_st_tcb_at2)
           apply simp
          apply (clarsimp simp: cte_wp_at_ctes_of capHasProperty_def)
         apply (wp asyncIPCCancel_st_tcb' sts_st_tcb_neq' getEndpoint_wp gts_wp'|wpc)+
  apply clarsimp
  done

lemma suspend_st_tcb_at':
  "\<lbrace>\<lambda>s. (t\<noteq>t' \<longrightarrow> st_tcb_at' P t' s) \<and> (t=t' \<longrightarrow> P Inactive)\<rbrace>
  suspend t
  \<lbrace>\<lambda>_. st_tcb_at' P t'\<rbrace>"
  apply (simp add: suspend_def unless_def)
  apply (cases "t=t'")
  apply (simp|wp ipcCancel_st_tcb_at' sts_st_tcb')+
  done

end