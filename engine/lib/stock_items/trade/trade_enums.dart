// ── Demand Reach ─────────────────────────────────────────────────────────────
// Controls how demand for a good propagates across species lines.

enum DemandReach {
  speciesOnly,    // Biochemically/culturally locked — near zero outside producing species
  // e.g. humanoid medicine, Krakkar war-rations
  speciesCore,    // Strong at home, thin curiosity/collector demand elsewhere
  // e.g. void artifacts, chrono-recordings
  political,      // Follows authority/influence kernels regardless of species
  // e.g. federation documents, shipping manifests
  crossCultural,  // Moderate demand across species lines — luxury/vice goods
  // e.g. narcotics with broad-spectrum effect, exotic foods
}

// ── Alien Demand Driver ───────────────────────────────────────────────────────
// For goods with speciesCore reach, what drives thin demand in alien systems?

enum AlienDemandDriver {
  xenomancyAndWealth,   // Scholars, collectors, mystics
  militancy,            // Weapons-adjacent, martial cultures
  commerce,             // High-commerce worlds import luxury goods
  tech,                 // High-tech worlds want exotic inputs
  population,           // Dense worlds need more of everything
}

// ── Stat Type ─────────────────────────────────────────────────────────────────
// Which planet/species stats drive demand intensity for a good.

enum StatType {
  tech,
  population,
  industry,
  commerce,
  militancy,
  xenomancy,
  wealth,
  fedLevel,   // proximity to federation authority
}
