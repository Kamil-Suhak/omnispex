use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum WishlistPriority {
    Low = 1,
    #[default]
    Medium = 2,
    High = 3,
    Critical = 4,
}

impl WishlistPriority {
    pub fn label(&self) -> &'static str {
        match self {
            WishlistPriority::Low => "Low",
            WishlistPriority::Medium => "Medium",
            WishlistPriority::High => "High",
            WishlistPriority::Critical => "Critical",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum AcquisitionState {
    #[default]
    Wishlist = 0,
    Ordered = 1,
    Unbuilt = 2,
    Assembled = 3,
    Primed = 4,
    BattleReady = 5,
    ParadeReady = 6,
}

impl AcquisitionState {
    pub fn label(&self) -> &'static str {
        match self {
            AcquisitionState::Wishlist => "To Buy / Wishlist",
            AcquisitionState::Ordered => "Ordered / In Transit",
            AcquisitionState::Unbuilt => "In Box / Unbuilt",
            AcquisitionState::Assembled => "Assembled",
            AcquisitionState::Primed => "Primed",
            AcquisitionState::BattleReady => "Battle Ready",
            AcquisitionState::ParadeReady => "Parade Ready",
        }
    }

    pub fn is_acquired(&self) -> bool {
        !matches!(self, AcquisitionState::Wishlist | AcquisitionState::Ordered)
    }

    pub fn is_painted(&self) -> bool {
        matches!(
            self,
            AcquisitionState::BattleReady | AcquisitionState::ParadeReady
        )
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WishlistItem {
    pub id: String,
    pub faction_id: String,
    pub faction_name: String,
    pub unit_id: String,
    pub unit_name: String,
    pub quantity_desired: u32,
    #[serde(default)]
    pub quantity_owned: u32,
    pub points_per_unit: u32,
    pub priority: WishlistPriority,
    pub state: AcquisitionState,
    #[serde(default)]
    pub notes: String,
    pub updated_at_iso: String,
}

impl WishlistItem {
    pub fn total_points_desired(&self) -> u32 {
        self.quantity_desired * self.points_per_unit
    }

    pub fn remaining_to_acquire(&self) -> u32 {
        self.quantity_desired.saturating_sub(self.quantity_owned)
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct WishlistSummary {
    pub faction_filter: Option<String>,
    pub total_distinct_units: usize,
    pub total_boxes_desired: u32,
    pub total_boxes_owned: u32,
    pub total_boxes_remaining: u32,
    pub total_points_desired: u32,
    pub total_points_owned: u32,
    pub critical_priority_count: usize,
    pub high_priority_count: usize,
    pub acquired_entries_count: usize,
    pub painted_entries_count: usize,
    pub acquisition_progress_percent: f64,
    pub painting_progress_percent: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum WishlistSortField {
    #[default]
    PriorityDesc,
    NameAsc,
    PointsDesc,
    StateAsc,
}

/// Inserts or updates a wishlist item for a specific faction.
/// If an entry for the same `(faction_id, unit_id or unit_name)` already exists and `item.id` does not match,
/// it updates the existing entry in-place rather than creating a duplicate row or accidentally inflating quantity.
pub fn upsert_wishlist_item(items: &mut Vec<WishlistItem>, item: WishlistItem) -> WishlistItem {
    if let Some(existing) = items.iter_mut().find(|existing| {
        existing.id == item.id
            || (existing.faction_id.eq_ignore_ascii_case(&item.faction_id)
                && (existing.unit_id.eq_ignore_ascii_case(&item.unit_id)
                    || existing.unit_name.eq_ignore_ascii_case(&item.unit_name)))
    }) {
        existing.quantity_desired = item.quantity_desired.max(1);
        existing.quantity_owned = item.quantity_owned;
        existing.points_per_unit = item.points_per_unit;
        existing.priority = item.priority;
        existing.state = item.state;
        if !item.notes.trim().is_empty() || existing.id == item.id {
            existing.notes = item.notes;
        }
        existing.updated_at_iso = item.updated_at_iso;
        existing.clone()
    } else {
        let mut clean = item;
        clean.quantity_desired = clean.quantity_desired.max(1);
        items.push(clean.clone());
        clean
    }
}

pub fn filter_and_sort_wishlist(
    items: &[WishlistItem],
    faction_id: Option<&str>,
    query: &str,
    priority_filter: Option<WishlistPriority>,
    state_filter: Option<AcquisitionState>,
    sort_by: WishlistSortField,
) -> Vec<WishlistItem> {
    let q = query.trim().to_lowercase();
    let mut filtered: Vec<WishlistItem> = items
        .iter()
        .filter(|item| {
            if let Some(fid) = faction_id {
                let fid_clean = fid.trim();
                if !fid_clean.is_empty()
                    && !fid_clean.eq_ignore_ascii_case("All Factions")
                    && !item.faction_id.eq_ignore_ascii_case(fid_clean)
                    && !item.faction_name.eq_ignore_ascii_case(fid_clean)
                {
                    return false;
                }
            }
            if let Some(pf) = priority_filter {
                if item.priority != pf {
                    return false;
                }
            }
            if let Some(sf) = state_filter {
                if item.state != sf {
                    return false;
                }
            }
            if !q.is_empty() {
                let matches_name = item.unit_name.to_lowercase().contains(&q);
                let matches_faction = item.faction_name.to_lowercase().contains(&q);
                let matches_notes = item.notes.to_lowercase().contains(&q);
                if !matches_name && !matches_faction && !matches_notes {
                    return false;
                }
            }
            true
        })
        .cloned()
        .collect();

    match sort_by {
        WishlistSortField::PriorityDesc => {
            filtered.sort_by(|a, b| {
                b.priority
                    .cmp(&a.priority)
                    .then_with(|| a.unit_name.cmp(&b.unit_name))
            });
        }
        WishlistSortField::NameAsc => {
            filtered.sort_by(|a, b| a.unit_name.cmp(&b.unit_name));
        }
        WishlistSortField::PointsDesc => {
            filtered.sort_by(|a, b| {
                b.total_points_desired()
                    .cmp(&a.total_points_desired())
                    .then_with(|| a.unit_name.cmp(&b.unit_name))
            });
        }
        WishlistSortField::StateAsc => {
            filtered.sort_by(|a, b| {
                a.state
                    .cmp(&b.state)
                    .then_with(|| b.priority.cmp(&a.priority))
            });
        }
    }

    filtered
}

pub fn compute_wishlist_summary(
    items: &[WishlistItem],
    faction_id: Option<&str>,
) -> WishlistSummary {
    let scoped: Vec<&WishlistItem> = items
        .iter()
        .filter(|item| {
            if let Some(fid) = faction_id {
                let fid_clean = fid.trim();
                if !fid_clean.is_empty() && !fid_clean.eq_ignore_ascii_case("All Factions") {
                    return item.faction_id.eq_ignore_ascii_case(fid_clean)
                        || item.faction_name.eq_ignore_ascii_case(fid_clean);
                }
            }
            true
        })
        .collect();

    let total_distinct_units = scoped.len();
    let total_boxes_desired: u32 = scoped.iter().map(|i| i.quantity_desired).sum();
    let total_boxes_owned: u32 = scoped
        .iter()
        .map(|i| i.quantity_owned.min(i.quantity_desired))
        .sum();
    let total_boxes_remaining = total_boxes_desired.saturating_sub(total_boxes_owned);

    let total_points_desired: u32 = scoped.iter().map(|i| i.total_points_desired()).sum();
    let total_points_owned: u32 = scoped
        .iter()
        .map(|i| i.quantity_owned.min(i.quantity_desired) * i.points_per_unit)
        .sum();

    let critical_priority_count = scoped
        .iter()
        .filter(|i| i.priority == WishlistPriority::Critical)
        .count();
    let high_priority_count = scoped
        .iter()
        .filter(|i| i.priority == WishlistPriority::High)
        .count();
    let acquired_entries_count = scoped.iter().filter(|i| i.state.is_acquired()).count();
    let painted_entries_count = scoped.iter().filter(|i| i.state.is_painted()).count();

    let acquisition_progress_percent = if total_boxes_desired > 0 {
        (total_boxes_owned as f64 / total_boxes_desired as f64) * 100.0
    } else {
        0.0
    };

    let painting_progress_percent = if total_distinct_units > 0 {
        (painted_entries_count as f64 / total_distinct_units as f64) * 100.0
    } else {
        0.0
    };

    WishlistSummary {
        faction_filter: faction_id.map(|s| s.to_string()),
        total_distinct_units,
        total_boxes_desired,
        total_boxes_owned,
        total_boxes_remaining,
        total_points_desired,
        total_points_owned,
        critical_priority_count,
        high_priority_count,
        acquired_entries_count,
        painted_entries_count,
        acquisition_progress_percent,
        painting_progress_percent,
    }
}

