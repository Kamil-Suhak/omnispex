use rand::Rng;
use serde::{Deserialize, Serialize};
use std::fmt;
use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ValueExpr {
    Flat(u32),
    D3,
    D6,
    D6Plus(u32),
    TwoD6,
    TwoD6Plus(u32),
}

impl ValueExpr {
    pub fn roll(&self, rng: &mut impl Rng) -> u32 {
        match *self {
            ValueExpr::Flat(n) => n,
            ValueExpr::D3 => rng.gen_range(1..=3),
            ValueExpr::D6 => rng.gen_range(1..=6),
            ValueExpr::D6Plus(n) => rng.gen_range(1..=6) + n,
            ValueExpr::TwoD6 => rng.gen_range(1..=6) + rng.gen_range(1..=6),
            ValueExpr::TwoD6Plus(n) => rng.gen_range(1..=6) + rng.gen_range(1..=6) + n,
        }
    }

    pub fn min(&self) -> u32 {
        match *self {
            ValueExpr::Flat(n) => n,
            ValueExpr::D3 => 1,
            ValueExpr::D6 => 1,
            ValueExpr::D6Plus(n) => 1 + n,
            ValueExpr::TwoD6 => 2,
            ValueExpr::TwoD6Plus(n) => 2 + n,
        }
    }

    pub fn max(&self) -> u32 {
        match *self {
            ValueExpr::Flat(n) => n,
            ValueExpr::D3 => 3,
            ValueExpr::D6 => 6,
            ValueExpr::D6Plus(n) => 6 + n,
            ValueExpr::TwoD6 => 12,
            ValueExpr::TwoD6Plus(n) => 12 + n,
        }
    }

    pub fn expected_value(&self) -> f64 {
        match *self {
            ValueExpr::Flat(n) => n as f64,
            ValueExpr::D3 => 2.0,
            ValueExpr::D6 => 3.5,
            ValueExpr::D6Plus(n) => 3.5 + n as f64,
            ValueExpr::TwoD6 => 7.0,
            ValueExpr::TwoD6Plus(n) => 7.0 + n as f64,
        }
    }
}

impl fmt::Display for ValueExpr {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ValueExpr::Flat(n) => write!(f, "{}", n),
            ValueExpr::D3 => write!(f, "D3"),
            ValueExpr::D6 => write!(f, "D6"),
            ValueExpr::D6Plus(n) => write!(f, "D6+{}", n),
            ValueExpr::TwoD6 => write!(f, "2D6"),
            ValueExpr::TwoD6Plus(n) => write!(f, "2D6+{}", n),
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct ParseDiceError(pub String);

impl fmt::Display for ParseDiceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Invalid dice expression: {}", self.0)
    }
}

impl std::error::Error for ParseDiceError {}

impl FromStr for ValueExpr {
    type Err = ParseDiceError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let cleaned = s.trim().to_uppercase().replace(' ', "");
        if let Ok(num) = cleaned.parse::<u32>() {
            return Ok(ValueExpr::Flat(num));
        }

        if cleaned == "D3" {
            return Ok(ValueExpr::D3);
        }
        if cleaned == "D6" {
            return Ok(ValueExpr::D6);
        }
        if cleaned == "2D6" {
            return Ok(ValueExpr::TwoD6);
        }

        if let Some(rest) = cleaned.strip_prefix("D6+") {
            if let Ok(bonus) = rest.parse::<u32>() {
                return Ok(ValueExpr::D6Plus(bonus));
            }
        }
        if let Some(rest) = cleaned.strip_prefix("2D6+") {
            if let Ok(bonus) = rest.parse::<u32>() {
                return Ok(ValueExpr::TwoD6Plus(bonus));
            }
        }
        if let Some(rest) = cleaned.strip_prefix("D3+") {
            if let Ok(bonus) = rest.parse::<u32>() {
                // Approximate D3+X if ever encountered, or return D6Plus if matched
                if bonus == 0 {
                    return Ok(ValueExpr::D3);
                }
            }
        }

        Err(ParseDiceError(s.to_string()))
    }
}
