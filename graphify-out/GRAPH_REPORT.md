# Graph Report - marketplace_app  (2026-09-21)

## Corpus Check
- 248 files · ~126,855 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1904 nodes · 2633 edges · 113 communities (99 shown, 10 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 86 edges (avg confidence: 0.85)
- Token cost: 644,258 input · 0 output

## Community Hubs (Navigation)
- Design Tokens And Theme
- Windows Plugin Registration
- Reel Player Screen
- Clerk Auth Acceptance Criteria
- Log In Screen
- Product Card Widget
- Product Detail Screen
- Reel Data Model
- App Text Field Widget
- User Profile Repository
- Item Card Widget
- App Startup And Supabase Wiring
- Postgres Security And Indexing Rules
- Discover Screen
- Product Riverpod Providers
- Linux Plugin Registration
- App Icon And Info Row
- Phone Field Widget
- Home Screen
- Country Dial Code Picker
- Order Mock Repository
- Router Route Table
- Edit Profile Screen
- Product Mock Repository
- Reel Mock Repository
- Product Data Model
- Product Detail Sections
- Dual Supabase Client Switch
- Interests Screen
- Sign Up Verification Wiring
- App Button Widget
- Product Info Card Widget
- Onboarding Illustrations And Logos
- Package Dependencies And Assets
- Email Address Screen
- Phone Number Screen
- User Profile Model
- Verification Code Section
- Repository Provider Wiring
- Order Data Model
- Reels Grid Screen
- Supabase Backend Decisions
- Bottom Navigation Bar
- Shared Widget Tests
- Cart Item Model
- Get Started Screen
- Supabase Repository Implementations
- Postgres Index Types And Vacuum
- Profile Screen
- Category Chip Widget
- Cart Order Reel Providers
- Segmented Tabs Widget
- Onboarding Screen Tests
- Postgres Reference Writing Guidelines
- iOS macOS Plugin Registration
- Interests Category Artwork
- Onboarding Preferences
- Auth Error And Resend Rules
- Search Field Widget
- Size Selector Widget
- Icon And Row Widget Tests
- Notifications And Welcome Screens
- Most Visited Item Widget
- Spec Table Widget
- Notifications Screen Tests
- Toggle And Tabs Tests
- Project Conventions
- Sign In Verification Wiring
- Windows Runner Entry Point
- Orphaned Verify Email Screen
- Item Card Search Tests
- Postgres Connection And Pooling
- Design System Reference
- Cart Repository Layer
- Reels And Data Model Decisions
- Navigation Shell
- Web App Manifest
- Discover Screen Decisions
- iOS App Delegate
- Phone Field Tests
- Account Deletion Edge Functions
- Add To Cart Toggle
- Theme And Welcome Tests
- Product Card Tests
- iOS Engine Bridge
- macOS App Delegate
- Order Status Badge
- Product Scope Features
- Welcome And Profile Entry Points
- Sign Up Flow Tests
- Windows Build Targets
- Interests Screen Tests
- Text Field Tests
- Notification Time Label
- macOS App Lifecycle
- macOS Flutter Window
- Mock Sellers And Row Mappers
- Linux Build Targets
- Composite And Partial Indexes
- Android Main Activity
- Batch Insert And N Plus One
- Advisory And Skip Locked
- Covering Index Scans
- Mock Network Delay
- Apple Store Handle
- Bershka Store Handle
- Nike Store Handle
- Pull And Bear Store Handle
- Nullable String Type

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 24 edges
2. `Spec 0004: Adopt Clerk for real user authentication` - 20 edges
3. `marketplace_app package manifest` - 20 edges
4. `MessageHandler` - 12 edges
5. `Spec 0005: Build the real Profile screen` - 12 edges
6. `AuthSessionController` - 11 edges
7. `Shopscroll Marketplace App` - 11 edges
8. `productsProvider` - 10 edges
9. `InterestsScreen` - 10 edges
10. `FlutterWindow` - 10 edges

## Surprising Connections (you probably didn't know these)
- `ProfileAnonymousView` --semantically_similar_to--> `AC-1: Browsing needs no sign in, welcome screen shown once`  [INFERRED] [semantically similar]
  lib/features/profile/profile_anonymous_view.dart → docs/specs/0004-clerk-authentication/index.md
- `LogInScreen` --references--> `Spec 0004: Adopt Clerk for real user authentication`  [AMBIGUOUS]
  lib/features/onboarding/log_in_screen.dart → docs/specs/0004-clerk-authentication/index.md
- `currentUserProfileProvider` --references--> `UserProfileRepository`  [EXTRACTED]
  docs/specs/0005-profile-screen/index.md → lib/data/repositories/user_profile_repository.dart
- `UserProfileRepository.updateUserProfile (new write)` --implements--> `UserProfileRepository`  [EXTRACTED]
  docs/specs/0005-profile-screen/index.md → lib/data/repositories/user_profile_repository.dart
- `Diamond Ring in Red Velvet Box (Interests card art)` --references--> `InterestsScreen`  [INFERRED]
  assets/interests/diamond_ring.png → lib/features/onboarding/interests_screen.dart

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Connection Management Rule Family (conn- prefix)** — _agents_skills_supabase_postgres_best_practices_references_conn_pooling_connection_pooling, _agents_skills_supabase_postgres_best_practices_references_conn_limits_connection_limits, _agents_skills_supabase_postgres_best_practices_references_conn_idle_timeout_idle_connection_timeouts, _agents_skills_supabase_postgres_best_practices_references_conn_prepared_statements_prepared_statements_with_pooling [EXTRACTED 1.00]
- **Concurrency & Locking Rule Family (lock- prefix)** — _agents_skills_supabase_postgres_best_practices_references_lock_advisory_advisory_locks, _agents_skills_supabase_postgres_best_practices_references_lock_deadlock_prevention_consistent_lock_ordering, _agents_skills_supabase_postgres_best_practices_references_lock_short_transactions_short_transactions, _agents_skills_supabase_postgres_best_practices_references_lock_skip_locked_skip_locked_queue [EXTRACTED 1.00]
- **Data Access Round-Trip Reduction Pattern** — _agents_skills_supabase_postgres_best_practices_references_data_batch_inserts_batch_inserts, _agents_skills_supabase_postgres_best_practices_references_data_n_plus_one_eliminate_n_plus_one, _agents_skills_supabase_postgres_best_practices_references_data_pagination_cursor_pagination, _agents_skills_supabase_postgres_best_practices_references_data_upsert_upsert_on_conflict [INFERRED 0.85]
- **Postgres Index Strategy Family** — _agents_skills_supabase_postgres_best_practices_references_query_missing_indexes_index_where_join_columns, _agents_skills_supabase_postgres_best_practices_references_query_composite_indexes_composite_index, _agents_skills_supabase_postgres_best_practices_references_query_covering_indexes_covering_index, _agents_skills_supabase_postgres_best_practices_references_query_partial_indexes_partial_index, _agents_skills_supabase_postgres_best_practices_references_query_index_types_index_type_selection, _agents_skills_supabase_postgres_best_practices_references_schema_foreign_key_indexes_fk_index [INFERRED 0.85]
- **Supabase RLS Security Model** — _agents_skills_supabase_postgres_best_practices_references_security_rls_basics_row_level_security, _agents_skills_supabase_postgres_best_practices_references_security_rls_performance_rls_optimization, _agents_skills_supabase_postgres_best_practices_references_security_privileges_least_privilege, _agents_skills_supabase_skill_security_checklist, _agents_skills_supabase_skill_views_bypass_rls, _agents_skills_supabase_skill_bola_to_authenticated [INFERRED 0.85]
- **Large Table Scaling Playbook** — _agents_skills_supabase_postgres_best_practices_references_schema_partitioning_table_partitioning, _agents_skills_supabase_postgres_best_practices_references_query_index_types_brin, _agents_skills_supabase_postgres_best_practices_references_monitor_vacuum_analyze_autovacuum_tuning, _agents_skills_supabase_postgres_best_practices_references_monitor_pg_stat_statements_pg_stat_statements [INFERRED 0.75]
- **Spec-Driven Feature Lifecycle (scope to spec to verify)** — docs_scope_scope_shopscroll_scope, docs_specs_0002_reels_screen_spec_0002, docs_verify_manual_verify_steps, agents_spec_directory_convention [INFERRED 0.85]
- **Swappable Data Access Stack** — agents_mock_data_layer, agents_riverpod_providers, agents_repository_pattern, docs_specs_0003_supabase_backend_index_supabase_platform, agents_as_if_endpoint_convention [INFERRED 0.95]
- **Figma-Sourced UI Pipeline** — design_figma_file_shopscroll_ui, agents_design_tokens, design_shared_widget_catalog, agents_figma_node_documentation, design_figma_code_audit [INFERRED 0.85]
- **Redesigned Clerk sign up flow screens** — lib_features_onboarding_welcome_screen_welcomescreen, lib_features_onboarding_get_started_screen_getstartedscreen, lib_features_onboarding_phone_number_screen_phonenumberscreen, lib_features_onboarding_email_address_screen_emailaddressscreen, lib_features_onboarding_verification_code_section_verificationcodesection, lib_features_onboarding_interests_screen_interestsscreen, lib_features_onboarding_enable_notifications_screen_enablenotificationsscreen, lib_features_onboarding_setting_up_account_screen_settingupaccountscreen [EXTRACTED 1.00]
- **Anonymous to real session switch and merge** — lib_core_auth_auth_session_controller_authsessioncontroller, lib_core_auth_active_supabase_client_activesupabaseclientprovider, lib_core_auth_active_supabase_client_buildclerkbackedclient, docs_specs_0004_clerk_authentication_index_merge_anonymous_identity, lib_data_repositories_repository_providers_repositoryproviders [EXTRACTED 1.00]
- **Account deletion paths and shared cleanup** — lib_features_profile_profile_screen_profilescreen, supabase_functions_delete_account_index_deleteaccount, supabase_functions_clerk_webhook_index_clerkwebhook, supabase_functions__shared_delete_user_data_deleteuserdata, lib_features_profile_agents_deleteuser_broken_workaround [EXTRACTED 1.00]
- **Interests screen category card artwork set** — assets_interests_diamond_ring_diamondring, assets_interests_painting_painting, assets_interests_party_decor_partydecor, assets_interests_sneakers_sneakers, assets_interests_sofa_sofa, assets_interests_toy_train_toytrain, lib_features_onboarding_interests_screen_interestsscreen [INFERRED 0.95]
- **Onboarding shopping category taxonomy** — assets_interests_diamond_ring_jewellerycategory, assets_interests_painting_artcategory, assets_interests_party_decor_partysuppliescategory, assets_interests_sneakers_footwearcategory, assets_interests_sofa_furniturecategory, assets_interests_toy_train_toyscategory [INFERRED 0.85]

## Communities (113 total, 10 thin omitted)

### Community 0 - "Design Tokens And Theme"
Cohesion: 0.02
Nodes (127): accent100, accent200, accent300, accent400, accent500, accent600, accentAlpha10, accentAlpha50 (+119 more)

### Community 1 - "Windows Plugin Registration"
Cohesion: 0.05
Nodes (57): PluginRegistry, RECT, unique_ptr, RegisterPlugins(), DartProject, HWND, LPARAM, LRESULT (+49 more)

### Community 2 - "Reel Player Screen"
Cohesion: 0.04
Nodes (50): ChewieController?, _avatarSize, chewieController, color, commentCount, _controllers, _createController, createState (+42 more)

### Community 3 - "Clerk Auth Acceptance Criteria"
Cohesion: 0.05
Nodes (47): AC-10: Failed merge retried once, sign in still succeeds, AC-11: Sign in rate limiting and lockout provided by Clerk, AC-2: Passwordless sign up via name, username, phone or email, one time code, AC-3: Anonymous cart and orders merge into the new real account, AC-4: user_profiles buyer row upserted and kept in sync on sign in, AC-5: Owned rows readable or writable only by their owning session, AC-6: Signing out returns to anonymous browsing, AC-7: Expired real session falls back to anonymous browsing (+39 more)

### Community 4 - "Log In Screen"
Cohesion: 0.06
Nodes (35): AccountType, _AccountTypeToggle, build, _busy, _channel, _codeController, _codeError, _continue (+27 more)

### Community 5 - "Product Card Widget"
Cohesion: 0.06
Nodes (35): _AddToCartButton, _Avatar, _avatarSize, _bigWidth, build, _cardWidth, child, colorOptions (+27 more)

### Community 6 - "Product Detail Screen"
Cohesion: 0.06
Nodes (33): _addedToCart, _avatarSize, createState, description, excludeProductId, _height, icon, label (+25 more)

### Community 7 - "Reel Data Model"
Cohesion: 0.06
Nodes (31): ../../data/models/reel.dart, caption, commentCount, copyWith, createdAt, fromJson, id, isAvailable (+23 more)

### Community 8 - "App Text Field Widget"
Cohesion: 0.06
Nodes (31): FormFieldValidator, AppTextField, _AppTextFieldState, _border, build, controller, createState, dispose (+23 more)

### Community 9 - "User Profile Repository"
Cohesion: 0.07
Nodes (25): Exception, getSellers, getUserProfileById, updateUserProfile, username, UsernameTakenException, package:marketplace_app/data/mock/mock_products.dart, package:marketplace_app/data/mock/mock_reels.dart (+17 more)

### Community 10 - "Item Card Widget"
Cohesion: 0.07
Nodes (28): _Avatar, _avatarSize, build, _buildTrailing, _deleteIconSize, _gap, imageUrl, ItemCard (+20 more)

### Community 11 - "App Startup And Supabase Wiring"
Cohesion: 0.08
Nodes (27): core/auth/auth_session_controller.dart, core/config/supabase_config.dart, core/onboarding/onboarding_prefs.dart, core/router/app_router.dart, data/repositories/supabase/supabase_cart_repository.dart, data/repositories/supabase/supabase_order_repository.dart, data/repositories/supabase/supabase_product_repository.dart, data/repositories/supabase/supabase_reel_repository.dart (+19 more)

### Community 12 - "Postgres Security And Indexing Rules"
Cohesion: 0.09
Nodes (27): Feedback Issue Template, Supabase Skill Changelog, pg_stat_statements Query Analysis, Index WHERE and JOIN Columns, Sequential Scan, Idempotent Constraint Creation in Migrations, pg_constraint Catalog, ON DELETE CASCADE Cost (+19 more)

### Community 13 - "Discover Screen"
Cohesion: 0.07
Nodes (26): AsyncValue, ../../data/models/product.dart, _activeCategoryIndex, _applySearch, _banners, _BannerSlide, _categories, createState (+18 more)

### Community 14 - "Product Riverpod Providers"
Cohesion: 0.12
Nodes (26): ConsumerState, ConsumerStatefulWidget, ConsumerWidget, dealsProductsProvider, productByIdProvider, productsByCategoryProvider, productsProvider, watch (+18 more)

### Community 15 - "Linux Plugin Registration"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 16 - "App Icon And Info Row"
Cohesion: 0.09
Nodes (23): app_icon.dart, Color?, AppIcon, AppIconGlyph, build, color, glyph, _icons (+15 more)

### Community 17 - "Phone Field Widget"
Cohesion: 0.08
Nodes (25): country_dial_code.dart, build, controller, country, createState, dispose, enabled, _errorStyle (+17 more)

### Community 18 - "Home Screen"
Cohesion: 0.08
Nodes (25): ../../data/providers/product_providers.dart, _activeCategoryIndex, _BecomeASellerButton, _CampaignBannerCarousel, _CampaignBannerCarouselState, _categories, _controller, createState (+17 more)

### Community 19 - "Country Dial Code Picker"
Cohesion: 0.08
Nodes (24): app_text_field.dart, int get, build, countryDialCodes, _CountryDialCodeSheet, _CountryDialCodeSheetState, createState, defaultCountryDialCode (+16 more)

### Community 20 - "Order Mock Repository"
Cohesion: 0.09
Nodes (20): mockCartItems, mockOrders, getOrderById, getOrders, MockOrderRepository, getOrderById, getOrders, OrderRepository (+12 more)

### Community 21 - "Router Route Table"
Cohesion: 0.08
Nodes (23): app_shell.dart, ../config/clerk_config.dart, ../../features/catalog/home_screen.dart, ../../features/catalog/product_detail_screen.dart, ../../features/discover/discover_screen.dart, ../../features/onboarding/email_address_screen.dart, ../../features/onboarding/enable_notifications_screen.dart, ../../features/onboarding/get_started_screen.dart (+15 more)

### Community 22 - "Edit Profile Screen"
Cohesion: 0.09
Nodes (23): ../../data/providers/user_profile_providers.dart, data/repositories/repository_providers.dart, ../../data/repositories/user_profile_repository.dart, AC-6: Inline validation for blank or taken fields blocks saving, UserProfileRepository.updateUserProfile (new write), userProfileByIdProvider, userProfileRepositoryProvider, _bioController (+15 more)

### Community 23 - "Product Mock Repository"
Cohesion: 0.09
Nodes (20): mockProducts, getDealsProducts, getProductById, getProducts, getProductsByCategory, MockProductRepository, getDealsProducts, getProductById (+12 more)

### Community 24 - "Reel Mock Repository"
Cohesion: 0.09
Nodes (20): mockReels, getReelById, getReels, getReelsByStore, MockReelRepository, getReelById, getReels, getReelsByStore (+12 more)

### Community 25 - "Product Data Model"
Cohesion: 0.08
Nodes (23): category, colorOptions, copyWith, createdAt, description, fromJson, id, imageUrl (+15 more)

### Community 26 - "Product Detail Sections"
Cohesion: 0.09
Nodes (24): _BottomActionBar, _HeroImage, _IconCircle, _MiniProductTile, _PriceAndStockRow, _QuantityButton, _RefundMethodRow, _SectionHeaderRow (+16 more)

### Community 27 - "Dual Supabase Client Switch"
Cohesion: 0.09
Nodes (22): active_supabase_client.dart, Supabase Third Party Auth (Clerk provider), Two Supabase clients, not one, activeSupabaseClientProvider, buildClerkBackedClient, anonymousClient, clerkAuth, clerkBackedClient (+14 more)

### Community 28 - "Interests Screen"
Cohesion: 0.09
Nodes (22): build, _cardAspectRatio, category, _columns, createState, example, hashCode, image (+14 more)

### Community 29 - "Sign Up Verification Wiring"
Cohesion: 0.10
Nodes (21): AC-14: Name and username from step one saved onto the new account, Redesigned passwordless sign up flow, _authState, _context, describeOutstandingFields, email, _isPhone, _maybe (+13 more)

### Community 30 - "App Button Widget"
Cohesion: 0.09
Nodes (21): AppButton, AppButtonSize, AppButtonVariant, background, _bigWidth, borderColor, build, _ButtonSpec (+13 more)

### Community 31 - "Product Info Card Widget"
Cohesion: 0.09
Nodes (21): _Avatar, _avatarSize, build, _cardWidth, child, description, _descriptionStyle, height (+13 more)

### Community 32 - "Onboarding Illustrations And Logos"
Cohesion: 0.10
Nodes (20): AnimationController, Apple Logo Brand Mark, Google Logo Brand Mark, OAuth Provider Brand Marks, Account Loader Spinner Ring, Enable Notifications Illustration, Duration, build (+12 more)

### Community 33 - "Package Dependencies And Assets"
Cohesion: 0.11
Nodes (21): iOS launch screen assets note, assets/icons/ asset directory, assets/illustrations/ asset directory, assets/interests/ asset directory, cached_network_image, chewie, clerk_auth, clerk_flutter (+13 more)

### Community 34 - "Email Address Screen"
Cohesion: 0.10
Nodes (20): _back, build, _codeController, _codeError, _continue, createState, dispose, _email (+12 more)

### Community 35 - "Phone Number Screen"
Cohesion: 0.10
Nodes (20): _back, build, _codeController, _codeError, _continue, _country, createState, dispose (+12 more)

### Community 36 - "User Profile Model"
Cohesion: 0.10
Nodes (19): avatarUrl, bio, copyWith, email, followerCount, followingCount, fromJson, id (+11 more)

### Community 37 - "Verification Code Section"
Cohesion: 0.11
Nodes (18): dart:async, build, codeLength, controller, createState, dispose, errorText, initState (+10 more)

### Community 38 - "Repository Provider Wiring"
Cohesion: 0.11
Nodes (17): getSellers, getUserProfileById, MockUserProfileRepository, updateUserProfile, cartRepositoryProvider, orderRepositoryProvider, productRepositoryProvider, reelRepositoryProvider (+9 more)

### Community 39 - "Order Data Model"
Cohesion: 0.11
Nodes (17): cart_item.dart, double?, copyWith, createdAt, deliveryFee, deliveryMethod, estimatedDelivery, fromJson (+9 more)

### Community 40 - "Reels Grid Screen"
Cohesion: 0.12
Nodes (17): ../../data/providers/reel_providers.dart, reelsProvider, build, _applySearch, build, _CenteredMessage, createState, dispose (+9 more)

### Community 41 - "Supabase Backend Decisions"
Cohesion: 0.15
Nodes (17): Repository Pattern, Anonymous-to-Real Identity Merge, Anonymous Session Reuse at Startup, Anonymous Sign In, dart-define Configuration and Secrets, Read-Only Catalog (no write policies), Row Level Security Model, Spec 0003: Adopt Supabase as the Backend (+9 more)

### Community 42 - "Bottom Navigation Bar"
Cohesion: 0.12
Nodes (16): Color get, AppBottomNavBar, AppTabBarVariant, AppTabItem, _borderColor, build, _buildTab, currentItem (+8 more)

### Community 43 - "Shared Widget Tests"
Cohesion: 0.12
Nodes (13): Container, package:marketplace_app/shared/widgets/app_bottom_nav_bar.dart, package:marketplace_app/shared/widgets/category_chip.dart, package:marketplace_app/shared/widgets/most_visited_item.dart, package:marketplace_app/shared/widgets/order_status_badge.dart, main, wrap, main (+5 more)

### Community 44 - "Cart Item Model"
Cohesion: 0.12
Nodes (16): DateTime, double get, int?, addedAt, CartItem, copyWith, fromJson, id (+8 more)

### Community 45 - "Get Started Screen"
Cohesion: 0.12
Nodes (15): build, _continue, createState, dispose, _formKey, _fullNameController, GetStartedScreen, _GetStartedScreenState (+7 more)

### Community 46 - "Supabase Repository Implementations"
Cohesion: 0.15
Nodes (13): getClerkToken, supabasePublishableKey, supabaseUrl, _client, getCartItems, _client, getSellers, getUserProfileById (+5 more)

### Community 47 - "Postgres Index Types And Vacuum"
Cohesion: 0.13
Nodes (15): Autovacuum Scale Factor Tuning, Postgres Query Planner, VACUUM and ANALYZE Statistics Maintenance, BRIN Index (large time-series), B-tree Index, GIN Index (JSONB, arrays, full-text), GiST Index (geometric, ranges, KNN), Hash Index (equality only) (+7 more)

### Community 48 - "Profile Screen"
Cohesion: 0.13
Nodes (14): ClerkAuthState?, core/auth/active_supabase_client.dart, ../../data/models/user_profile.dart, authState, _confirmDeleteAccount, _openComingSoon, profile, rows (+6 more)

### Community 49 - "Category Chip Widget"
Cohesion: 0.13
Nodes (13): IconData, build, CategoryChip, icon, _iconSize, label, _letterSpacing, onTap (+5 more)

### Community 50 - "Cart Order Reel Providers"
Cohesion: 0.16
Nodes (11): cartItemsProvider, watch, orderByIdProvider, ordersProvider, watch, reelByIdProvider, reelsByStoreProvider, watch (+3 more)

### Community 51 - "Segmented Tabs Widget"
Cohesion: 0.13
Nodes (14): active, activeIndex, bottomPadding, build, distribution, fontSize, inactiveColor, label (+6 more)

### Community 52 - "Onboarding Screen Tests"
Cohesion: 0.13
Nodes (13): package:marketplace_app/features/onboarding/email_address_screen.dart, package:marketplace_app/features/onboarding/phone_number_screen.dart, disposeScreen, main, reachVerifyStage, screen, wrap, disposeScreen (+5 more)

### Community 53 - "Postgres Reference Writing Guidelines"
Cohesion: 0.15
Nodes (14): supabase-postgres-best-practices Release History, Error-First Structure, Impact Level Scale, Quantified Impact, Semantic Naming in Examples, Writing Guidelines for Postgres References, Rule Section Definitions, Postgres Rule Reference Template (+6 more)

### Community 54 - "iOS macOS Plugin Registration"
Cohesion: 0.14
Nodes (13): app_links, device_info_plus, file_selector_macos, Foundation, package_info_plus, passkeys_darwin, shared_preferences_foundation, sqflite_darwin (+5 more)

### Community 55 - "Interests Category Artwork"
Cohesion: 0.18
Nodes (14): Diamond Ring in Red Velvet Box (Interests card art), Jewellery Category, Art & Wall Decor Category, Framed Abstract Painting (Interests card art), Colorful Party Hats (Interests card art), Party Supplies Category, Footwear Category, Blue Running Sneakers (Interests card art) (+6 more)

### Community 56 - "Onboarding Preferences"
Cohesion: 0.14
Nodes (12): bool get, hasSeenWelcome, markWelcomeSeen, onboardingPrefsProvider, _prefs, _seenWelcomeKey, _assetPath, build (+4 more)

### Community 57 - "Auth Error And Resend Rules"
Cohesion: 0.20
Nodes (14): AC-12: Every Clerk error surfaced visibly, field errors shown inline, AC-13: 30 second resend countdown, phone locks after code sent, ClerkErrorListener error surfacing, EmailAddressScreen, _EmailAddressScreenState, LogInScreen, _LogInScreenState, PhoneNumberScreen (+6 more)

### Community 58 - "Search Field Widget"
Cohesion: 0.14
Nodes (13): build, controller, _hintStyle, hintText, _iconSize, onChanged, onSubmitted, onTap (+5 more)

### Community 59 - "Size Selector Widget"
Cohesion: 0.14
Nodes (13): active, build, _horizontalPadding, label, _labelStyle, onChanged, onTap, selected (+5 more)

### Community 60 - "Icon And Row Widget Tests"
Cohesion: 0.17
Nodes (10): Icon, package:marketplace_app/shared/widgets/app_icon.dart, package:marketplace_app/shared/widgets/info_row.dart, package:marketplace_app/shared/widgets/settings_row.dart, main, wrap, main, wrap (+2 more)

### Community 61 - "Notifications And Welcome Screens"
Cohesion: 0.15
Nodes (11): build, _illustrationSize, onBack, onEnable, onRemindLater, build, onLogIn, onSignUp (+3 more)

### Community 62 - "Most Visited Item Widget"
Cohesion: 0.15
Nodes (12): _boxSize, build, _iconLabelGap, _iconSize, iconUrl, _labelLetterSpacing, _labelStyle, MostVisitedItem (+4 more)

### Community 63 - "Spec Table Widget"
Cohesion: 0.15
Nodes (12): borderLeft, build, _Cell, label, SpecTable, _SpecTableRow, text, _textStyle (+4 more)

### Community 64 - "Notifications Screen Tests"
Cohesion: 0.15
Nodes (10): package:flutter_svg/flutter_svg.dart, package:marketplace_app/features/onboarding/enable_notifications_screen.dart, package:marketplace_app/shared/widgets/app_button.dart, package:marketplace_app/shared/widgets/enable_notifications_illustration.dart, main, screen, wrap, main (+2 more)

### Community 65 - "Toggle And Tabs Tests"
Cohesion: 0.15
Nodes (10): package:marketplace_app/shared/widgets/add_to_cart_toggle.dart, package:marketplace_app/shared/widgets/notification_time_label.dart, package:marketplace_app/shared/widgets/segmented_tabs.dart, main, wrap, main, wrap, main (+2 more)

### Community 66 - "Project Conventions"
Cohesion: 0.18
Nodes (12): Stray .expo Folder Note, Dual Backend Rule (Mock vs Supabase), Feature Directory Layout, Mock Data Layer, Riverpod Provider Layer, Shopscroll Marketplace App, docs/specs Numbering Convention, Widget Test Conventions (+4 more)

### Community 67 - "Sign In Verification Wiring"
Cohesion: 0.17
Nodes (11): BuildContext, core/config/clerk_config.dart, _authState, _context, maybe, resendCode, sendCode, SignInVerification (+3 more)

### Community 68 - "Windows Runner Entry Point"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 69 - "Orphaned Verify Email Screen"
Cohesion: 0.20
Nodes (11): verify, build, _codeController, createState, dispose, _submit, VerifyEmailScreen, _VerifyEmailScreenState (+3 more)

### Community 70 - "Item Card Search Tests"
Cohesion: 0.17
Nodes (9): package:flutter/material.dart, package:marketplace_app/main.dart, package:marketplace_app/shared/widgets/item_card.dart, package:marketplace_app/shared/widgets/search_field.dart, main, wrap, main, wrap (+1 more)

### Community 71 - "Postgres Connection And Pooling"
Cohesion: 0.18
Nodes (11): Configure Idle Connection Timeouts, Set Appropriate Connection Limits, work_mem x max_connections Memory Budget, Use Connection Pooling for All Applications, Transaction vs Session Pool Mode, Use Prepared Statements Correctly with Pooling, Use Cursor-Based Pagination Instead of OFFSET, Use UPSERT for Insert-or-Update Operations (+3 more)

### Community 72 - "Design System Reference"
Cohesion: 0.22
Nodes (11): AppIcon Glyph Mapping Convention, Design Tokens, Figma Node Documentation Convention, Color Palette Token Ramps, Figma vs Code Token Audit, Figma File ShopScroll-UI, Shared Widget Catalog, Shopscroll Design System Reference (+3 more)

### Community 73 - "Cart Repository Layer"
Cohesion: 0.20
Nodes (9): ../cart_repository.dart, CartRepository, getCartItems, getCartItems, MockCartRepository, SupabaseCartRepository, ../../mock/mock_cart_items.dart, ../../models/cart_item.dart (+1 more)

### Community 74 - "Reels And Data Model Decisions"
Cohesion: 0.22
Nodes (11): Bounded Video Controller Window, Full Screen Reel Player, Session-Only Like/Save State, Shop the Look Bottom Sheet, Unavailable Reel Treatment, Order Item Price Snapshotting, Per-User reel_likes / reel_saves Relations, Relational Data Model (9 Tables) (+3 more)

### Community 75 - "Navigation Shell"
Cohesion: 0.18
Nodes (9): AppShell, build, navigationShell, package:go_router/go_router.dart, package:marketplace_app/features/profile/profile_anonymous_view.dart, ../../shared/widgets/app_bottom_nav_bar.dart, StatefulNavigationShell, main (+1 more)

### Community 76 - "Web App Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 77 - "Discover Screen Decisions"
Cohesion: 0.33
Nodes (10): As-If REST Endpoint Doc Convention, Centralized go_router Routing, Client-Side Search Filter, ComingSoonScreen Placeholder Branches, Per-Section Loading/Error/Empty States, Persistent Navigation Shell (StatefulShellRoute), Spec 0001: Build the Discover Screen, Store Grid Section (+2 more)

### Community 78 - "iOS App Delegate"
Cohesion: 0.24
Nodes (6): Flutter, FlutterSceneDelegate, SceneDelegate, RunnerTests, UIKit, XCTestCase

### Community 79 - "Phone Field Tests"
Cohesion: 0.20
Nodes (8): package:marketplace_app/shared/widgets/country_dial_code.dart, package:marketplace_app/shared/widgets/phone_field.dart, main, borderColor, main, prefixColor, textColor, wrap

### Community 80 - "Account Deletion Edge Functions"
Cohesion: 0.29
Nodes (4): ClerkUserDeletedEvent, issuer, deleteUserData(), serviceRoleClient()

### Community 81 - "Add To Cart Toggle"
Cohesion: 0.22
Nodes (8): added, AddToCartDisplay, AddToCartToggle, build, display, _iconSize, _letterSpacing, onTap

### Community 82 - "Theme And Welcome Tests"
Cohesion: 0.22
Nodes (7): package:marketplace_app/core/theme/app_theme.dart, package:marketplace_app/features/onboarding/setting_up_account_screen.dart, package:marketplace_app/features/onboarding/welcome_screen.dart, main, wrap, main, wrap

### Community 83 - "Product Card Tests"
Cohesion: 0.22
Nodes (7): package:marketplace_app/shared/widgets/product_card.dart, package:marketplace_app/shared/widgets/product_info_card.dart, SizedBox, main, wrap, main, wrap

### Community 84 - "iOS Engine Bridge"
Cohesion: 0.25
Nodes (6): Any, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Bool, UIApplication

### Community 85 - "macOS App Delegate"
Cohesion: 0.32
Nodes (4): Cocoa, FlutterMacOS, RunnerTests, XCTest

### Community 86 - "Order Status Badge"
Cohesion: 0.25
Nodes (7): ../../data/models/order.dart, build, _letterSpacing, OrderStatusBadge, status, _width, static const double

### Community 87 - "Product Scope Features"
Cohesion: 0.32
Nodes (8): Auth (Clerk) Feature, Discover Screen Feature, Log In Feature (spec pending), Profile Screen Feature, Reels Screen Feature, Shopscroll Product Scope, Supabase Backend Feature, Tracer Bullet Build Approach

### Community 88 - "Welcome And Profile Entry Points"
Cohesion: 0.32
Nodes (8): AC-1: Browsing needs no sign in, welcome screen shown once, AC-1: Signed in Profile tab renders the full Figma page, OnboardingPrefs, app_router.dart route table, WelcomeScreen, ProfileAnonymousView, ProfileScreen, SettingsRow

### Community 89 - "Sign Up Flow Tests"
Cohesion: 0.25
Nodes (6): package:flutter_test/flutter_test.dart, package:marketplace_app/features/onboarding/get_started_screen.dart, package:marketplace_app/features/onboarding/sign_up_verification.dart, main, wrap, main

### Community 90 - "Windows Build Targets"
Cohesion: 0.36
Nodes (8): Windows generated_plugins.cmake include, Windows project build (marketplace_app), Windows flutter INTERFACE library target, Windows flutter_assemble target, flutter_wrapper_app static library, flutter_wrapper_plugin static library, Windows generated_plugin_registrant.cc, Windows runner executable target

### Community 91 - "Interests Screen Tests"
Cohesion: 0.29
Nodes (6): DecoratedBox, package:marketplace_app/features/onboarding/interests_screen.dart, decorationOf, main, screen, wrap

### Community 92 - "Text Field Tests"
Cohesion: 0.29
Nodes (6): FormState, package:marketplace_app/shared/widgets/app_text_field.dart, innerField, main, wrap, TextFormField

### Community 93 - "Notification Time Label"
Cohesion: 0.33
Nodes (5): ../../core/theme/app_theme.dart, build, checked, NotificationTimeLabel, text

### Community 94 - "macOS App Lifecycle"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 95 - "macOS Flutter Window"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 96 - "Mock Sellers And Row Mappers"
Cohesion: 0.33
Nodes (4): mockSellers, productFromRow, userProfileFromRow, ../models/user_profile.dart

### Community 97 - "Linux Build Targets"
Cohesion: 0.47
Nodes (6): Linux generated_plugins.cmake include, Linux project build (runner, marketplace_app binary), Linux flutter INTERFACE library target, Linux flutter_assemble target, Linux generated_plugin_registrant.cc, Linux runner executable target

### Community 98 - "Composite And Partial Indexes"
Cohesion: 0.67
Nodes (3): Composite Index for Multi-Column Queries, Leftmost Prefix Rule, Partial Index for Filtered Queries

## Ambiguous Edges - Review These
- `LogInScreen` → `Spec 0004: Adopt Clerk for real user authentication`  [AMBIGUOUS]
  lib/features/onboarding/AGENTS.md · relation: references
- `Shopscroll Marketplace App` → `Stray .expo Folder Note`  [AMBIGUOUS]
  .expo/README.md · relation: conceptually_related_to
- `Jewellery Category` → `Footwear Category`  [AMBIGUOUS]
  assets/interests/sneakers.png · relation: semantically_similar_to

## Knowledge Gaps
- **1037 isolated node(s):** `supabaseUrl`, `supabasePublishableKey`, `getClerkToken`, `ref`, `clerkAuth` (+1032 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1244 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `LogInScreen` and `Spec 0004: Adopt Clerk for real user authentication`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Shopscroll Marketplace App` and `Stray .expo Folder Note`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Jewellery Category` and `Footwear Category`?**
  _Edge tagged AMBIGUOUS (relation: semantically_similar_to) - confidence is low._
- **Why does `_` connect `Clerk Auth Acceptance Criteria` to `Onboarding Preferences`, `Dual Supabase Client Switch`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Why does `ProfileScreen` connect `Welcome And Profile Entry Points` to `Profile Screen`, `Clerk Auth Acceptance Criteria`, `Product Riverpod Providers`, `Edit Profile Screen`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **Why does `Spec 0004: Adopt Clerk for real user authentication` connect `Clerk Auth Acceptance Criteria` to `Welcome And Profile Entry Points`, `Auth Error And Resend Rules`, `Dual Supabase Client Switch`, `Sign Up Verification Wiring`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **What connects `supabaseUrl`, `supabasePublishableKey`, `getClerkToken` to the rest of the system?**
  _1037 weakly-connected nodes found - possible documentation gaps or missing edges._