# Northline Components delivery

Workshop materials for fictional purchase order PO-2026-1137.

- `01-first-delivery/` has the packing list, Revision A supplier quote, and warehouse label.
- `02-follow-up/` has the missing inspection certificate. Its long filename is intentional.
- `03-revised-quote/` has a different quotation with the same file name and a different revision.
- `expected-delivery.txt` lists the four expected names.
- `expected-delivery-duplicates.txt` contains whitespace and a repeated name for parser verification.
- `fill-manifest.py` types the canonical list into a focused Android emulator text field.
- `send-to-emulator.py` sends explicitly selected files to a loopback port forwarded to a LocalSend Android emulator.

In a fresh live history, the first delivery should match 3 names and leave 1 unmatched.
Sending the certificate should match all 4. In the isolated workshop launcher, history
starts with 2 matches, 1 unmatched, and 1 name to review. The certificate-looking text
message in that dataset cannot satisfy the checklist. The launcher adds the receipt
when requested. Its records are held in memory for that launch.

[LocalSend transfer protocol](https://github.com/localsend/protocol#4-file-transfer-http-aka-upload-api)
