# Deploying mupt.org from scratch

This repository uses two separate deployment paths:

1. OpenTofu runs from an administrator's local machine. It creates the Cloudflare Pages project, a Pages-only deployment token, and the GitHub Actions secrets and variables. Once `mupt.org` is an active Cloudflare zone, it can also create the custom domain and DNS record.
2. GitHub Actions builds the Hugo site and uploads it to Cloudflare Pages. The workflows are installed only after the infrastructure apply succeeds.

OpenTofu state for the root configuration is stored in a private Cloudflare R2 bucket through R2's S3-compatible API. Creating that bucket is a one-time bootstrap operation with local state.

## What the deployment creates

The root [`main.tf`](main.tf) creates or manages:

- a Cloudflare Pages direct-upload project named `mupt`, with `main` as its production branch;
- an account-owned Cloudflare API token named `mupt_token` with `Pages Write` permission;
- the GitHub Actions secrets `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN`;
- the GitHub Actions variables `CLOUDFLARE_PROJECT_NAME` and `MAIN_REPO`;
- optionally, the `mupt.org` Pages custom domain and a proxied apex CNAME to the project's `pages.dev` hostname.

The bootstrap [`bootstrap/main.tf`](bootstrap/main.tf) creates only the R2 bucket.

## Prerequisites

Before beginning, confirm all of the following:

- If configuring the custom domain during the first apply, `mupt.org` is an active zone in the Cloudflare account. Otherwise, leave `custom_domain` empty and add the domain in a later apply.
- Before enabling the custom domain, ensure there is no conflicting A, AAAA, or CNAME record at the `mupt.org` apex. Preserve any unrelated DNS records. If the intended apex record already exists outside OpenTofu, import it instead of creating a duplicate.
- The GitHub repository `MuPT-hub/mupt.org` exists and the person running OpenTofu can administer its Actions secrets and variables.
- [OpenTofu](https://opentofu.org/docs/intro/install/) 1.x, Git, and Python 3 are installed locally.
- The repository is cloned and the shell is at its root.

The checked-in provider constraint intentionally pins Cloudflare provider `5.9.0`. Do not upgrade it casually: the upstream module currently depends on behavior that changed in later 5.x releases.

## 1. Record the Cloudflare account ID

In the [Cloudflare dashboard](https://dash.cloudflare.com), select the account that owns `mupt.org`, open **Workers & Pages**, and copy the Account ID shown in the account details. It is a 32-character hexadecimal value.

Set it for the current shell:

```sh
export TF_VAR_cloudflare_account_id='YOUR_32_CHARACTER_ACCOUNT_ID'
```

Do not put real credentials or IDs in a committed `.tfvars` file.

## 2. Create the local bootstrap API token in Cloudflare

This is the short-lived administrative token used for the entire local infrastructure session. Its bearer value authenticates the Cloudflare provider, and the R2 credentials issued alongside it authenticate the state backend. It is not the narrower Pages deployment token that the root apply later installs in GitHub.

Creating an account-owned token requires a Cloudflare Super Administrator. In the selected account, go to **Manage Account → Account API Tokens → Create Token** and create a custom token. If the dashboard instead presents the user-token flow, use **My Profile → API Tokens → Create Custom Token** and grant the same resource access.

Give the token a name such as `mupt-opentofu-YYYY-MM-DD`, set a short expiration that leaves enough time to finish the deployment, and grant:

| Scope | Permission | Access | Why it is needed |
| --- | --- | --- | --- |
| Account | Account API Tokens | Write | Look up the Pages permission group and create `mupt_token` |
| Account | Pages | Write | Create and manage the Pages project and custom domain |
| Account | Workers R2 Storage | Write | Create/manage the state bucket and access its state objects |
| Zone | Zone | Read | Find `mupt.org` by name when the custom domain is enabled |
| Zone | DNS | Write | Create and manage the apex CNAME when the custom domain is enabled |

Restrict the account permissions to the account recorded above and the zone permissions to `mupt.org`. If `mupt.org` is not a Cloudflare zone yet, the two zone permissions may be omitted for the initial deployment; include them when minting a token for the later custom-domain deployment. The dashboard may label edit-level access as **Edit** rather than **Write**.

On the confirmation page, immediately save all three credentials; Cloudflare will not show the secrets again:

- the API token value;
- the R2 Access Key ID; and
- the R2 Secret Access Key.

The API token value authenticates Cloudflare provider operations. The Access Key ID and Secret Access Key authenticate the S3-compatible state backend. They belong to the same short-lived account token but are not interchangeable.

Export all three values for the current shell without adding them to a shell profile:

```sh
export CLOUDFLARE_API_TOKEN='YOUR_API_TOKEN_VALUE'
export AWS_ACCESS_KEY_ID='YOUR_R2_ACCESS_KEY_ID'
export AWS_SECRET_ACCESS_KEY='YOUR_R2_SECRET_ACCESS_KEY'
```

Cloudflare documents the relevant permissions for [account token creation](https://developers.cloudflare.com/api/resources/accounts/subresources/tokens/methods/create/), [Pages](https://developers.cloudflare.com/pages/configuration/api/), [R2 bucket creation](https://developers.cloudflare.com/api/resources/r2/subresources/buckets/methods/create/), [zone lookup](https://developers.cloudflare.com/api/resources/zones/methods/list/), and [DNS writes](https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/create/).

## 3. Create the R2 state bucket with OpenTofu

Choose an account-unique bucket name containing only lowercase letters, numbers, and hyphens. The example below uses `mupt-opentofu-state`; change it if that name already exists in the account.

```sh
tofu -chdir=bootstrap init
tofu -chdir=bootstrap plan \
  -var="cloudflare_account_id=${TF_VAR_cloudflare_account_id}" \
  -var='bucket_name=mupt-opentofu-state'
tofu -chdir=bootstrap apply \
  -var="cloudflare_account_id=${TF_VAR_cloudflare_account_id}" \
  -var='bucket_name=mupt-opentofu-state'
```

Review the plan before approving the apply. It should create exactly one `cloudflare_r2_bucket`.

The bootstrap stack deliberately keeps local state in `bootstrap/terraform.tfstate`; a remote backend cannot be used until its bucket exists. That file is ignored by Git, but it is still essential infrastructure state. Store an encrypted backup in the team's secrets system. Do not delete the bootstrap state and do not run `tofu destroy` in this directory unless deleting the remote-state bucket is genuinely intended.

## 4. Confirm the R2 S3 credentials are loaded

The root OpenTofu S3 backend uses the R2 Access Key ID and Secret Access Key saved in step 2. Confirm that all three Cloudflare values are present in the current shell without printing their contents:

```sh
test -n "${CLOUDFLARE_API_TOKEN}" \
  && test -n "${AWS_ACCESS_KEY_ID}" \
  && test -n "${AWS_SECRET_ACCESS_KEY}"
```

No output and a zero exit status mean all three variables are set. These credentials can read and modify the root state, which contains sensitive values. Keep them only for the infrastructure session, never commit them, and do not add them to GitHub Actions. See Cloudflare's [R2 API-token documentation](https://developers.cloudflare.com/r2/api/tokens/) and [remote backend guide](https://developers.cloudflare.com/terraform/advanced-topics/remote-backend/).

## 5. Create a GitHub token for the local apply

The GitHub provider uses `GITHUB_TOKEN` to write repository-level Actions secrets and variables. Create a fine-grained personal access token for `MuPT-hub/mupt.org` with:

- repository access limited to `MuPT-hub/mupt.org`;
- **Metadata: Read**;
- **Secrets: Read and write**; and
- **Variables: Read and write**.

The user owning the token must have sufficient repository administration access, and an organization that enforces SSO may require the token to be authorized for SSO. A classic PAT with `repo` scope also works but is broader.

```sh
export GITHUB_TOKEN='YOUR_GITHUB_TOKEN'
```

GitHub documents the permissions for [repository Actions secrets](https://docs.github.com/en/rest/actions/secrets) and [repository Actions variables](https://docs.github.com/en/rest/actions/variables).

## 6. Initialize the root configuration with the R2 backend

Use the same bucket name chosen in step 3. The endpoint contains the Cloudflare account ID, not the bucket name.

```sh
tofu init \
  -backend-config='bucket=mupt-opentofu-state' \
  -backend-config="endpoints={s3=\"https://${TF_VAR_cloudflare_account_id}.r2.cloudflarestorage.com\"}"
```

The root configuration fixes the state object key at `mupt/terraform.tfstate`. Backend settings and credentials are intentionally supplied outside source control. If this working copy was previously initialized with different backend settings, add `-reconfigure`. Use `-migrate-state` only when deliberately moving an existing state and after backing it up.

OpenTofu's [S3 backend documentation](https://opentofu.org/docs/language/settings/backends/s3/) explains the partial-configuration pattern. The R2-specific compatibility flags are already present in `main.tf`.

## 7. Plan and apply the site infrastructure locally

All five environment variables must still be set:

```text
CLOUDFLARE_API_TOKEN
TF_VAR_cloudflare_account_id
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
GITHUB_TOKEN
```

The `custom_domain` variable defaults to the empty string. Therefore, the first deployment works before `mupt.org` has been added to Cloudflare: OpenTofu skips the zone lookup, Pages custom domain, and DNS record. Do not set `TF_VAR_custom_domain` for that initial deployment.

Format, validate, and inspect the plan:

```sh
tofu fmt -check -recursive
tofu validate
tofu plan -out=mupt.tfplan
tofu show mupt.tfplan
```

Expected initial changes include a Pages project, a Pages-only account token, two GitHub Actions secrets, and two GitHub Actions variables. When `custom_domain` is empty, the plan must not contain a zone lookup, Pages domain, or DNS record. Apply only after checking the target account and repository:

```sh
tofu apply mupt.tfplan
```

The plan file is ignored by Git and contains sensitive data. Delete it securely when it is no longer needed.

After the apply, confirm:

- `tofu output subdomain` returns the expected `mupt.pages.dev` hostname;
- Cloudflare **Workers & Pages** contains the `mupt` project;
- GitHub **Settings → Secrets and variables → Actions** contains secrets `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN`; and
- the same GitHub page contains variables `CLOUDFLARE_PROJECT_NAME=mupt` and `MAIN_REPO=mupt-hub/mupt.org`.

The generated `CLOUDFLARE_API_TOKEN` is intentionally Pages-only. GitHub Actions does not receive the powerful local bootstrap token.

## 8. Add `mupt.org` after its Cloudflare zone is ready

Skip this step until Cloudflare shows `mupt.org` as an active zone and its authoritative nameservers are in use. Ensure the local `CLOUDFLARE_API_TOKEN` now also has **Zone: Read** and **DNS: Write** for `mupt.org`, then set:

```sh
export TF_VAR_custom_domain='mupt.org'
```

Create and review a new plan:

```sh
tofu plan -out=mupt-domain.tfplan
tofu show mupt-domain.tfplan
tofu apply mupt-domain.tfplan
```

The plan should add one `cloudflare_pages_domain` and one `cloudflare_dns_record`; it should not replace the Pages project or its deployment token. After the apply, confirm `mupt.org` appears under the Pages project's custom domains and Cloudflare DNS has a proxied apex CNAME targeting `mupt.pages.dev`.

Keep `TF_VAR_custom_domain=mupt.org` set for every subsequent plan and apply. Changing it back to an empty string tells OpenTofu to destroy the managed Pages domain and DNS record.

## 9. Install the static-site-tools workflows

Do this only after the infrastructure deployment in step 7 succeeds. The custom-domain step may happen before or after workflow installation. The upstream installer creates five workflows for Hugo: PR build, push build, staging deploy, production deploy, and preview cleanup.

For reproducibility, install from a reviewed static-site-tools commit rather than following its moving `main` branch. From the root of this repository:

```sh
mupt_tools_dir="$(mktemp -d)"
git clone https://github.com/omsf/static-site-tools.git "${mupt_tools_dir}/static-site-tools"
mupt_tools_ref="$(git -C "${mupt_tools_dir}/static-site-tools" rev-parse HEAD)"
python3 "${mupt_tools_dir}/static-site-tools/install.py" hugo \
  --site-dir . \
  --commit "${mupt_tools_ref}"
```

This writes the following files under `.github/workflows/` and pins their reusable workflow references to `mupt_tools_ref`:

```text
build-pr.yaml
build-push.yaml
cleanup-cloudflare.yaml
prod-cloudflare.yaml
stage-cloudflare.yaml
```

Review the generated workflows before committing them. In particular, verify that the source directory is `.`, the production branch is `main`, all `uses:` references are pinned to the reviewed commit, and the requested GitHub token permissions match the repository's policy. Then commit and push the workflows through the normal review process.

The upstream [static-site-tools overview](https://github.com/omsf/static-site-tools) explains the split build/deploy design used to support previews from forked pull requests.

## 10. Verify the first deployment

Pushing the workflow commit to `main` should trigger the production build and then the Cloudflare production deployment workflow. In GitHub's **Actions** tab, confirm both complete successfully. Then verify:

```sh
curl --fail --show-error --head https://mupt.pages.dev/
```

After completing step 8, also verify `https://mupt.org/`. DNS and TLS activation for a newly attached custom domain can take a few minutes. A pull request should additionally produce a preview deployment and a link in the PR; closing it should run the cleanup workflow.

## Routine infrastructure changes

Infrastructure remains a local operation. For each maintenance session, mint a new short-lived account API token in the Cloudflare dashboard with the permissions in step 2, save and export its API token value and R2 credential pair, set `TF_VAR_custom_domain=mupt.org` once the domain is managed, initialize with the same backend arguments, and run `tofu plan` followed by `tofu apply`. Never run the root configuration in GitHub Actions unless the deployment model is intentionally redesigned.

After the maintenance session, unset `CLOUDFLARE_API_TOKEN`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY` and allow the token to expire, or revoke it immediately in the Cloudflare dashboard. A future session uses a newly minted token and its newly supplied S3 credentials. Rotating the generated Pages token should be done through the root OpenTofu stack so the corresponding GitHub secret stays synchronized.

Do not manually edit resources managed by OpenTofu. If an emergency dashboard change is unavoidable, run a fresh plan afterward and reconcile the drift deliberately.

## Troubleshooting

- **`Authentication error (10000)` or `forbidden`:** confirm the correct Cloudflare account is selected and the bootstrap token has every permission in step 2 at the correct account/zone scope.
- **Cannot create the Pages deployment token:** the local token needs **Account API Tokens: Write**, and the caller must be allowed to manage account-owned tokens.
- **R2 `AccessDenied` during `tofu init`:** confirm `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` contain the R2 credentials shown alongside the current API token. Do not use the bearer token value directly as an S3 credential.
- **Backend bucket not found:** check the bucket name and confirm the endpoint uses the same Cloudflare account ID that owns the bucket.
- **GitHub `404` or `403`:** confirm repository access, Secrets and Variables write permissions, organization SSO authorization, and the repository spelling/case.
- **DNS record conflict:** inspect existing apex A, AAAA, and CNAME records. Import the intended existing record or remove it only after confirming it is obsolete.
- **Custom domain remains pending:** confirm Cloudflare is authoritative for `mupt.org`, the apex CNAME is proxied, and no conflicting record exists.
- **A later provider upgrade proposes token replacement:** do not apply blindly. Review the upstream static-site-tools compatibility issue referenced in `main.tf` and test the upgrade separately.
