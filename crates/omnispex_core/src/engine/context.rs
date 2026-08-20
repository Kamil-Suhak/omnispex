use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CombatContext {
    pub distance_inches: Option<u32>,
    pub is_stationary: bool,
    pub has_charged: bool,
    pub in_engagement_range: bool,
    pub target_has_benefit_of_cover: bool,
    pub target_visible: bool,
    pub attacker_advanced: bool,
}

impl Default for CombatContext {
    fn default() -> Self {
        Self {
            distance_inches: None,
            is_stationary: false,
            has_charged: false,
            in_engagement_range: false,
            target_has_benefit_of_cover: false,
            target_visible: true,
            attacker_advanced: false,
        }
    }
}

impl CombatContext {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_distance(mut self, distance: u32) -> Self {
        self.distance_inches = Some(distance);
        self
    }

    pub fn stationary(mut self, val: bool) -> Self {
        self.is_stationary = val;
        self
    }

    pub fn charged(mut self, val: bool) -> Self {
        self.has_charged = val;
        self
    }

    pub fn in_engagement_range(mut self, val: bool) -> Self {
        self.in_engagement_range = val;
        self
    }

    pub fn with_cover(mut self, val: bool) -> Self {
        self.target_has_benefit_of_cover = val;
        self
    }

    pub fn visible(mut self, val: bool) -> Self {
        self.target_visible = val;
        self
    }

    pub fn advanced(mut self, val: bool) -> Self {
        self.attacker_advanced = val;
        self
    }
}
