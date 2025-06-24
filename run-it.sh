#!/bin/sh

#
# Purpose:
#   Evaluate what has changed in newly released Zimbra patches to help administrators decide 
#   whether immediate patching is necessary or if it can be deferred to a scheduled maintenance window.
#
# Note:
#   This script assumes the following prerequisites have been completed, as it compares RPM files:
#
#   - extract_zimbra_rpms.sh: Downloads and extracts RPMs and associated scripts from the latest patch
#   - backup-zimbra-rpms.sh: Archives all currently installed RPMs to allow for comparison, 
#     even if the originals have been removed
#
# Summary:
#   - backup_dir: Contains output from backup-zimbra-rpms.sh (current installed RPMs)
#   - latest_dir: Contains output from extract_zimbra_rpms.sh (latest patch RPMs)
#

#
# Sample output:
#
#% ./run-it.sh 
#📦 Extracting old RPM: /home/jad/zimbra-rpm-backup/20250620_115012/zimbra-mbox-webclient-war-9.0.0.1745518276-1.r8.x86_64.rpm
#📦 Extracting new RPM: /home/jad/zimbra_rpms/zimbra-mbox-webclient-war-9.0.0.1749617601-1.r8.x86_64.rpm
#📄 Extracting install scripts...
#🧪 Skipping diffoscope (deep diff) by default. Use --deep to enable.
#⚖️  Unchanged jar: stax-ex-2.2.6.jar
#⚖️  Unchanged jar: jsr181-api-2.2.6.jar
#⚖️  Unchanged jar: streambuffer-2.2.6.jar
#⚖️  Unchanged jar: gmbal-api-only-2.2.6.jar
#🔎 Examining changed jar: zm-taglib-9.0.0.1732884576
#🧹 Decompiling changed classes in zm-taglib-9.0.0.1732884576...
#⚖️  Unchanged jar: policy-2.3.1.jar
#⚖️  Unchanged jar: jaxb-api-2.2.6.jar
#⚖️  Unchanged jar: jaxws-api-2.2.6.jar
#⚖️  Unchanged jar: jaxb-impl-2.2.6.jar
#🔎 Examining changed jar: zm-ajax-9.0.0.1744704911
#🧹 Decompiling changed classes in zm-ajax-9.0.0.1744704911...
#⚖️  Unchanged jar: mina-core-2.0.4.jar
#⚖️  Unchanged jar: jaxws-rt-4.0.0.jar
#✅ Comparison complete. See workspace: /home/jad/workspace_zimbra-mbox-webclient-war
#📦 Extracting old RPM: /home/jad/zimbra-rpm-backup/20250620_115012/zimbra-patch-9.0.0.1745584203.p45-2.r8.x86_64.rpm
#📦 Extracting new RPM: /home/jad/zimbra_rpms/zimbra-patch-9.0.0.1749649572.p46-2.r8.x86_64.rpm
#📄 Extracting install scripts...
#🧪 Skipping diffoscope (deep diff) by default. Use --deep to enable.
#⚖️  Unchanged jar: zm-voice-cisco-store.jar
#⚖️  Unchanged jar: com_zimbra_oo.jar
#⚖️  Unchanged jar: zimbraconvertd.jar
#⚖️  Unchanged jar: com_zimbra_xmbxsearch.jar
#⚖️  Unchanged jar: zm-ssdb-ephemeral-store-9.0.0.1650887639.jar
#⚖️  Unchanged jar: com_zimbra_clientuploader.jar
#⚖️  Unchanged jar: zm-taglib-9.0.0.1732884576.jar
#⚖️  Unchanged jar: bcmail-jdk15on-1.64.jar
#⚖️  Unchanged jar: zimbraldaputils.jar
#⚖️  Unchanged jar: clamscanner.jar
#⚖️  Unchanged jar: zmgql.jar
#⚖️  Unchanged jar: com_zimbra_cert_manager.jar
#⚖️  Unchanged jar: zsyncreverseproxy.jar
#⚖️  Unchanged jar: samlextn.jar
#⚖️  Unchanged jar: zimbrabackup.jar
#⚖️  Unchanged jar: zm-smime-store.jar
#⚖️  Unchanged jar: com_zimbra_bulkprovision.jar
#⚖️  Unchanged jar: saaj-impl-1.5.1.jar
#⚖️  Unchanged jar: zm-openid-consumer-store-9.0.0.1649089375.jar
#⚖️  Unchanged jar: zmnetworkgql.jar
#⚖️  Unchanged jar: zm-sync-common.jar
#⚖️  Unchanged jar: tricipherextn.jar
#⚖️  Unchanged jar: zmoauthsocial.jar
#⚖️  Unchanged jar: zm-oauth-social-common.jar
#⚖️  Unchanged jar: zm-sync-store.jar
#⚖️  Unchanged jar: tika-app-1.24.1.jar
#⚖️  Unchanged jar: zimbratwofactorauth.jar
#⚖️  Unchanged jar: nginx-lookup.jar
#✅ Comparison complete. See workspace: /home/jad/workspace_zimbra-patch
#📦 Extracting old RPM: /home/jad/zimbra-rpm-backup/20250620_115012/zimbra-mbox-admin-console-war-9.0.0.1732701570-1.r8.x86_64.rpm
#📦 Extracting new RPM: /home/jad/zimbra_rpms/zimbra-mbox-admin-console-war-9.0.0.1749644337-1.r8.x86_64.rpm
#📄 Extracting install scripts...
#🧪 Skipping diffoscope (deep diff) by default. Use --deep to enable.
#⚖️  Unchanged jar: stax-ex-2.2.6.jar
#⚖️  Unchanged jar: jsr181-api-2.2.6.jar
#⚖️  Unchanged jar: streambuffer-2.2.6.jar
#⚖️  Unchanged jar: gmbal-api-only-2.2.6.jar
#🔎 Examining changed jar: zm-taglib-9.0.0.1732884576
#🧹 Decompiling changed classes in zm-taglib-9.0.0.1732884576...
#⚖️  Unchanged jar: policy-2.3.1.jar
#⚖️  Unchanged jar: jaxb-api-2.2.6.jar
#⚖️  Unchanged jar: jaxws-api-2.2.6.jar
#⚖️  Unchanged jar: jaxb-impl-2.2.6.jar
#⚖️  Unchanged jar: jaxws-rt-4.0.0.jar
#❓ No matching old jar for: zm-admin-ajax-9.0.0.1748265733.jar
#✅ Comparison complete. See workspace: /home/jad/workspace_zimbra-mbox-admin-console-war
#


backup_dir="/home/jad/zimbra-rpm-backup/20250620_115012/"
latest_dir="/home/jad/zimbra_rpms"

./compare_zimbra_war_rpms_v2.sh zimbra-mbox-webclient-war  --backup-dir $backup_dir --latest-dir $latest_dir
./compare_zimbra_war_rpms_v2.sh zimbra-patch  --backup-dir $backup_dir --latest-dir $latest_dir
./compare_zimbra_war_rpms_v2.sh zimbra-mbox-admin-console-war  --backup-dir $backup_dir --latest-dir $latest_dir

exit 
