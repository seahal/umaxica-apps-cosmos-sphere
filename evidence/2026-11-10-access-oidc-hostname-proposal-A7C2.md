# Access OIDC Hostname Proposal — Unapplied

Date: 2026-11-10. Read-only Access HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`. Access has
extensive pre-existing uncommitted changes; this proposal compares against the observed working
files, not HEAD. Access is outside the session writable roots and was not edited or tested.

The approved source is `adr/cosmos-sphere-surfaces-and-rp-independence.md`, "Public Hostnames for
Core, Warp and Palm". The static store uses `PUBLIC_CORE_SERVICE_URL`, `PUBLIC_CORE_STAFF_URL`,
`PUBLIC_WARP_SERVICE_URL`, `PUBLIC_WARP_STAFF_URL`, and `PUBLIC_PALM_SERVICE_URL` plus boot host
values. Both sources must change together. They derive callback, post-logout and back-channel logout
URIs. The complete-match policy and Jump namespace graph require no algorithm change. Palm is
unchanged.

The public-only zero-context patch below covers the three environment files, fixed JWT issuer and
regional root metadata, production HostAuthorization, and Jump contract test literals. `.dev` values
and all non-public-variable lines are preserved. It is a proposal, not applied evidence or a passing
verification result. Its zero-context form requires `git apply --unidiff-zero` after review in an
authorized Access session; line positions may drift.

Run `test/values/oidc_client_registry_test.rb`, `test/services/oidc/client_registry_test.rb`,
`test/services/jump_rt`, `test/adapters/oidc_backchannel_logout_client_test.rb`,
`test/integration/jump_rt_return_verification_test.rb`, and `test/security` after application. Add
explicit rejection assertions for each retired client authority and exact callback/logout URI
registrations, as in the Sphere change. No test result is claimed here.

```diff
--- a/.env
+++ b/.env
@@ -171 +171 @@
-PUBLIC_CORE_CORPORATE_URL=jp.umaxica.com
+PUBLIC_CORE_CORPORATE_URL=www-jp.umaxica.com
@@ -173,2 +173,2 @@
-PUBLIC_CORE_SERVICE_URL=jp.umaxica.app
-PUBLIC_CORE_STAFF_URL=jp.umaxica.org
+PUBLIC_CORE_SERVICE_URL=www-jp.umaxica.app
+PUBLIC_CORE_STAFF_URL=www-jp.umaxica.org
@@ -187,3 +187,3 @@
-PUBLIC_WARP_CORPORATE_URL=www-jp.umaxica.com
-PUBLIC_WARP_SERVICE_URL=www-jp.umaxica.app
-PUBLIC_WARP_STAFF_URL=www-jp.umaxica.org
+PUBLIC_WARP_CORPORATE_URL=warp-jp.umaxica.com
+PUBLIC_WARP_SERVICE_URL=warp-jp.umaxica.app
+PUBLIC_WARP_STAFF_URL=warp-jp.umaxica.org
--- a/.env.local
+++ b/.env.local
@@ -85,6 +85,6 @@
-PUBLIC_WARP_CORPORATE_URL=www-jp.umaxica.com
-PUBLIC_WARP_SERVICE_URL=www-jp.umaxica.app
-PUBLIC_WARP_STAFF_URL=www-jp.umaxica.org
-PUBLIC_CORE_CORPORATE_URL=jp.umaxica.com
-PUBLIC_CORE_SERVICE_URL=jp.umaxica.app
-PUBLIC_CORE_STAFF_URL=jp.umaxica.org
+PUBLIC_WARP_CORPORATE_URL=warp-jp.umaxica.com
+PUBLIC_WARP_SERVICE_URL=warp-jp.umaxica.app
+PUBLIC_WARP_STAFF_URL=warp-jp.umaxica.org
+PUBLIC_CORE_CORPORATE_URL=www-jp.umaxica.com
+PUBLIC_CORE_SERVICE_URL=www-jp.umaxica.app
+PUBLIC_CORE_STAFF_URL=www-jp.umaxica.org
--- a/.env.container.devcontainer
+++ b/.env.container.devcontainer
@@ -93,6 +93,6 @@
-PUBLIC_WARP_SERVICE_URL=www-jp.umaxica.app
-PUBLIC_WARP_CORPORATE_URL=www-jp.umaxica.com
-PUBLIC_WARP_STAFF_URL=www-jp.umaxica.org
-PUBLIC_CORE_SERVICE_URL=jp.umaxica.app
-PUBLIC_CORE_CORPORATE_URL=jp.umaxica.com
-PUBLIC_CORE_STAFF_URL=jp.umaxica.org
+PUBLIC_WARP_SERVICE_URL=warp-jp.umaxica.app
+PUBLIC_WARP_CORPORATE_URL=warp-jp.umaxica.com
+PUBLIC_WARP_STAFF_URL=warp-jp.umaxica.org
+PUBLIC_CORE_SERVICE_URL=www-jp.umaxica.app
+PUBLIC_CORE_CORPORATE_URL=www-jp.umaxica.com
+PUBLIC_CORE_STAFF_URL=www-jp.umaxica.org
--- a/lib/jit_security_jwt_registry.rb
+++ b/lib/jit_security_jwt_registry.rb
@@ -56,4 +56,4 @@
-    "CORE_APP" => "https://jp.umaxica.app",
-    "CORE_ORG" => "https://jp.umaxica.org",
-    "WARP_APP" => "https://www-jp.umaxica.app",
-    "WARP_ORG" => "https://www-jp.umaxica.org",
+    "CORE_APP" => "https://www-jp.umaxica.app",
+    "CORE_ORG" => "https://www-jp.umaxica.org",
+    "WARP_APP" => "https://warp-jp.umaxica.app",
+    "WARP_ORG" => "https://warp-jp.umaxica.org",
--- a/app/values/regional_root_url_registry.rb
+++ b/app/values/regional_root_url_registry.rb
@@ -21 +21 @@
-      "jp" => "https://jp.umaxica.app/",
+      "jp" => "https://www-jp.umaxica.app/",
@@ -25 +25 @@
-      "jp" => "https://jp.umaxica.com/",
+      "jp" => "https://www-jp.umaxica.com/",
@@ -29 +29 @@
-      "jp" => "https://jp.umaxica.org/",
+      "jp" => "https://www-jp.umaxica.org/",
--- a/config/environments/production.rb
+++ b/config/environments/production.rb
@@ -178,0 +179,7 @@
+    "warp-jp.umaxica.app",
+    "warp-jp.umaxica.com",
+    "warp-jp.umaxica.org",
+    "www.umaxica.app",
+    "www.umaxica.com",
+    "www.umaxica.org",
+    # Core public authority uses only the canonical www-jp.* host family.
@@ -182,7 +188,0 @@
-    "www.umaxica.app",
-    "www.umaxica.com",
-    "www.umaxica.org",
-    # Core public authority uses only the canonical jp.* host family.
-    "jp.umaxica.app",
-    "jp.umaxica.com",
-    "jp.umaxica.org",
--- a/test/services/jump_rt/return_policy_test.rb
+++ b/test/services/jump_rt/return_policy_test.rb
@@ -120,2 +120,2 @@
-      "core-app-jp" => "https://jp.umaxica.app",
-      "core-org-jp" => "https://jp.umaxica.org",
+      "core-app-jp" => "https://www-jp.umaxica.app",
+      "core-org-jp" => "https://www-jp.umaxica.org",
@@ -123,2 +123,2 @@
-      "warp-app-jp" => "https://www-jp.umaxica.app",
-      "warp-org-jp" => "https://www-jp.umaxica.org",
+      "warp-app-jp" => "https://warp-jp.umaxica.app",
+      "warp-org-jp" => "https://warp-jp.umaxica.org",
--- a/test/services/jump_rt/surface_identity_test.rb
+++ b/test/services/jump_rt/surface_identity_test.rb
@@ -108 +108 @@
-      "WARP_ORG" => "www-jp.umaxica.org",
+      "WARP_ORG" => "warp-jp.umaxica.org",
--- a/test/services/jump_rt/issuer_test.rb
+++ b/test/services/jump_rt/issuer_test.rb
@@ -465 +465 @@
-      assert_equal "https://jp.umaxica.#{tld.downcase}", JumpRtSurface.issuer_origin("CORE_#{tld}")
+      assert_equal "https://www-jp.umaxica.#{tld.downcase}", JumpRtSurface.issuer_origin("CORE_#{tld}")
@@ -478,2 +478,2 @@
-    assert_equal "https://www-jp.umaxica.app", JumpRtSurface.issuer_origin("WARP_APP")
-    assert_equal "https://www-jp.umaxica.org", JumpRtSurface.issuer_origin("WARP_ORG")
+    assert_equal "https://warp-jp.umaxica.app", JumpRtSurface.issuer_origin("WARP_APP")
+    assert_equal "https://warp-jp.umaxica.org", JumpRtSurface.issuer_origin("WARP_ORG")
```
