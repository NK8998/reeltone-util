# Auth database schema

PostgreSQL database `reeltone_auth`. Auth owns these tables and exposes identity through OpenID Connect. Reviews and the other apps can reference the immutable account UUID from the OIDC subject.

| Table | Fields | Constraints and behavior |
| --- | --- | --- |
| `accounts` | `id` UUID, `username`, `first_name`, `last_name`, `profile_picture_url`, `status`, `created_at`, `updated_at` | Require a case-insensitively unique username for completed accounts. Names and picture URL are nullable, since providers may omit them. Let users enter or edit these fields. Accept an HTTPS image URL until uploads are added. |
| `account_emails` | `id`, `account_id`, `email`, `normalized_email`, `verified_at`, `is_primary`, `created_at` | Keep one primary email per account and enforce uniqueness on normalized verified addresses. Record verification only after successful ReelTone verification or trusted provider evidence. |
| `password_credentials` | `account_id`, `password_hash`, `changed_at` | One Argon2id hash per account. OAuth-only accounts can omit this row. |
| `oauth_identities` | `id`, `account_id`, `provider`, `provider_user_id`, `provider_username`, `provider_display_name`, `provider_first_name`, `provider_last_name`, `provider_email`, `provider_email_verified`, `provider_picture_url`, `linked_at`, `last_login_at` | Unique on `(provider, provider_user_id)`. Nullable profile fields reflect what each provider actually returns. Provider email can help prefill a form. Linking requires proof of access to the existing ReelTone account. |
| `email_challenges` | `id`, `account_email_id`, `purpose`, `secret_digest`, `expires_at`, `attempt_count`, `consumed_at`, `created_at` | Separate verification and reset challenges. Store a keyed digest for short codes. Apply attempt and resend limits, and consume challenges atomically. |
| `oauth_login_attempts` | `id`, `provider`, `interaction_id`, `state_digest`, `pkce_verifier`, `nonce`, `expires_at`, `consumed_at` | Short-lived upstream login state tied to the originating Auth interaction. Keep the verifier server-side and consume the attempt once. |
| `oidc_artifacts` | `model`, `id`, `payload`, `expires_at`, `consumed_at`, `grant_id`, `interaction_uid`, `user_code` | Use `(model, id)` as the key. Back the OIDC provider adapter with this table for sessions, authorization codes and grants. Index grant revocation, interaction lookups, and expiry. |

Register Reviews, Stream, and Studio as OIDC clients in deployment configuration with exact callback URLs. Store client secrets and issuer signing keys in deployment secret storage.

## Provider field mapping

| Provider | Account key | Profile input |
| --- | --- | --- |
| Google | OIDC `sub` | `given_name` and `family_name` for names, `picture` for the avatar, and `email` plus `email_verified` for contact details when present. Ask the user to choose a ReelTone username. |
| GitHub | Numeric user `id`, stored as text | `login` as a username suggestion, `name` as a display name, and `avatar_url` for the avatar. Let the user provide first and last names. Use the verified email endpoint when available. |

Provider fields can seed an empty profile on first sign-in. Later provider updates should preserve profile fields the user edited. Request only identity scopes and discard upstream access tokens after fetching the profile for sign-in.

See the provider documentation for the supported fields. [Google OpenID Connect claims](https://developers.google.com/identity/openid-connect/openid-connect), [GitHub user API](https://docs.github.com/en/rest/users/users#get-the-authenticated-user), [GitHub email API](https://docs.github.com/en/rest/users/emails#list-email-addresses-for-the-authenticated-user)
