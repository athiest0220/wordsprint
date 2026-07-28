/// Development/testing switches.
///
/// ⚠️ SET THIS TO `false` BEFORE BUILDING THE STORE SUBMISSION.
///
/// When true, the app exposes payment-bypass shortcuts so the trial/paywall
/// flow can be tested without a live store product:
///   • the paywall's "unlock without paying" button, and
///   • the Settings "DEV — testing only" card (expire/reset trial).
/// These MUST NOT ship to the public. Flip to false and rebuild for release.
const bool kDevTools = false;
