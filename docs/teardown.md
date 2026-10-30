# Teardown

Do this after the demo, once the last test report and screenshots are committed.

```bash
./scripts/teardown.sh
```

It asks you to type the suffix, then:

1. Deletes `dp-lab-detection` (disables Macie and GuardDuty if we enabled them), `dp-lab-app`, the SecureString parameter and `dp-lab-datastores`
2. Empties the data and logs buckets, every version and delete marker, and deletes `dp-lab-s3`
3. Turns EBS default encryption back off
4. Deletes `dp-lab-kms`. This doesn't delete the keys immediately; it schedules them for deletion after 7 days. Until then you can still cancel with `aws kms cancel-key-deletion` if you find something you forgot
5. Empties the artifacts and CloudTrail buckets and deletes `dp-lab-foundation`
6. Removes `~/.dp-lab` from your CloudShell home

The keys go last on purpose: everything else is encrypted with them.

It leaves account-level S3 Block Public Access on. There's no reason to turn that off.

Check nothing tagged is left:

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=DataProtection \
  --query 'ResourceTagMappingList[].ResourceARN'
```

KMS keys pending deletion still show up here for 7 days. That's expected. Keep an eye on Billing for a few days after.

If a stack gets stuck in `DELETE_FAILED`, open it in the CloudFormation console, look at the Events tab, fix the cause (almost always a bucket that isn't empty), and run the script again.
