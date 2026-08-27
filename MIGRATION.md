# Migrations

## UID 999 -> GID 0 access model

The container previously ran as UID/GID 999. It now runs with **group 0**
and works under **any UID** (the default is 64604, matching the other
OpenVox containers). File access is granted through group 0 only,
no `chown` to a specific UID is needed.

In case of volume permission issues, run:

```shell
chgrp -R 0 <volume>
chmod -R g+rwX <volume>
```

On Kubernetes, setting `fsGroup: 0` in the pod's securityContext achieves
the same without manual steps.
