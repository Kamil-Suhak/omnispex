use crate::common::{AcquisitionState, WishlistPriority, WishlistSortField};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KtWishlistItem {
    pub id: String,
    pub faction_id: String,
    pub faction_name: String,
    pub operative_id: String,
    pub operative_name: String,
    pub role: String,
    pub quantity_desired: u32,
    #[serde(default)]
    pub quantity_owned: u32,
    #[serde(default)]
    pub priority: WishlistPriority,
    #[serde(default)]
    pub state: AcquisitionState,
    #[serde(default)]
    pub notes: String,
    #[serde(default)]
    pub updated_at_iso: String,
}

impl KtWishlistItem {
    pub fn remaining_to_acquire(&self) -> u32 {
        self.quantity_desired.saturating_sub(self.quantity_owned)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct KtWishlistSummary {
    pub total_distinct_operatives: usize,
    pub total_operatives_desired: u32,
    pub total_operatives_owned: u32,
    pub total_operatives_remaining: u32,
    pub painted_operatives_count: u32,
    pub count_by_state: HashMap<String, u32>,
    pub count_by_faction: HashMap<String, u32>,
}

pub fn upsert_kt_wishlist_item(items: &mut Vec<KtWishlistItem>, incoming: KtWishlistItem) {
    if let Some(existing) = items.iter_mut().find(|x| {
        x.id == incoming.id
            || (x.faction_id.eq_ignore_ascii_case(&incoming.faction_id)
                && x.operative_name
                    .eq_ignore_ascii_case(&incoming.operative_name))
    }) {
        existing.quantity_desired = incoming.quantity_desired.max(1);
        existing.quantity_owned = incoming.quantity_owned;
        existing.role = incoming.role;
        existing.priority = incoming.priority;
        existing.state = incoming.state;
        existing.notes = incoming.notes;
        existing.updated_at_iso = incoming.updated_at_iso;
    } else {
        items.push(incoming);
    }
}

pub fn filter_and_sort_kt_wishlist(
    items: &[KtWishlistItem],
    search_query: &str,
    faction_filter: Option<&str>,
    state_filter: Option<AcquisitionState>,
    priority_filter: Option<WishlistPriority>,
    sort_by: WishlistSortField,
) -> Vec<KtWishlistItem> {
    let q = search_query.trim().to_lowercase();
    let mut filtered: Vec<KtWishlistItem> = items
        .iter()
        .filter(|item| {
            let f_ok = faction_filter.map_or(true, |ff| {
                ff.is_empty()
                    || item.faction_id.eq_ignore_ascii_case(ff)
                    || item.faction_name.eq_ignore_ascii_case(ff)
            });
            let s_ok = state_filter.map_or(true, |sf| item.state == sf);
            let p_ok = priority_filter.map_or(true, |pf| item.priority == pf);
            let q_ok = q.is_empty()
                || item.operative_name.to_lowercase().contains(&q)
                || item.faction_name.to_lowercase().contains(&q)
                || item.role.to_lowercase().contains(&q)
                || item.notes.to_lowercase().contains(&q);
            f_ok && s_ok && p_ok && q_ok
        })
        .cloned()
        .collect();

    filtered.sort_by(|a, b| match sort_by {
        WishlistSortField::PriorityDesc => b
            .priority
            .cmp(&a.priority)
            .then_with(|| a.operative_name.cmp(&b.operative_name)),
        WishlistSortField::NameAsc => a.operative_name.cmp(&b.operative_name),
        WishlistSortField::FactionAsc => a
            .faction_name
            .cmp(&b.faction_name)
            .then_with(|| a.operative_name.cmp(&b.operative_name)),
        WishlistSortField::PointsDesc => b
            .quantity_desired
            .cmp(&a.quantity_desired)
            .then_with(|| a.operative_name.cmp(&b.operative_name)),
        WishlistSortField::StateAsc => a
            .state
            .cmp(&b.state)
            .then_with(|| b.priority.cmp(&a.priority)),
    });

    filtered
}

pub fn compute_kt_wishlist_summary(
    items: &[KtWishlistItem],
    faction_filter: Option<&str>,
) -> KtWishlistSummary {
    let mut summary = KtWishlistSummary::default();

    for item in items {
        if let Some(ff) = faction_filter {
            if !ff.is_empty()
                && !item.faction_id.eq_ignore_ascii_case(ff)
                && !item.faction_name.eq_ignore_ascii_case(ff)
            {
                continue;
            }
        }
        summary.total_distinct_operatives += 1;
        summary.total_operatives_desired += item.quantity_desired;
        summary.total_operatives_owned += item.quantity_owned;
        summary.total_operatives_remaining += item.remaining_to_acquire();
        if item.state.is_painted() {
            summary.painted_operatives_count += item.quantity_owned.max(item.quantity_desired);
        }

        *summary
            .count_by_state
            .entry(item.state.label().to_string())
            .or_insert(0) += item.quantity_desired;
        *summary
            .count_by_faction
            .entry(item.faction_name.clone())
            .or_insert(0) += item.quantity_desired;
    }

    summary
}
