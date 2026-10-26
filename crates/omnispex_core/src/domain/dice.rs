use rand::Rng;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fmt;
use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ValueExpr {
    Flat(u32),
    D3,
    D3Plus(u32),
    D6,
    D6Plus(u32),
    TwoD6,
    TwoD6Plus(u32),
    ThreeD6,
    ThreeD6Plus(u32),
}

impl ValueExpr {
    pub fn roll(&self, rng: &mut impl Rng) -> u32 {
        match *self {
            ValueExpr::Flat(n) => n,
            ValueExpr::D3 => rng.gen_range(1..=3),
            ValueExpr::D3Plus(n) => rng.gen_range(1..=3) + n,
            ValueExpr::D6 => rng.gen_range(1..=6),
            ValueExpr::D6Plus(n) => rng.gen_range(1..=6) + n,
            ValueExpr::TwoD6 => rng.gen_range(1..=6) + rng.gen_range(1..=6),
            ValueExpr::TwoD6Plus(n) => rng.gen_range(1..=6) + rng.gen_range(1..=6) + n,
            ValueExpr::ThreeD6 => {
                rng.gen_range(1..=6) + rng.gen_range(1..=6) + rng.gen_range(1..=6)
            }
            ValueExpr::ThreeD6Plus(n) => {
                rng.gen_range(1..=6) + rng.gen_range(1..=6) + rng.gen_range(1..=6) + n
            }
        }
    }

    pub fn min(&self) -> u32 {
        match *self {
            ValueExpr::Flat(n) => n,
            ValueExpr::D3 => 1,
            ValueExpr::D3Plus(n) => 1 + n,
            ValueExpr::D6 => 1,
            ValueExpr::D6Plus(n) => 1 + n,
            ValueExpr::TwoD6 => 2,
            ValueExpr::TwoD6Plus(n) => 2 + n,
            ValueExpr::ThreeD6 => 3,
            ValueExpr::ThreeD6Plus(n) => 3 + n,
        }
    }

    pub fn max(&self) -> u32 {
        match *self {
            ValueExpr::Flat(n) => n,
            ValueExpr::D3 => 3,
            ValueExpr::D3Plus(n) => 3 + n,
            ValueExpr::D6 => 6,
            ValueExpr::D6Plus(n) => 6 + n,
            ValueExpr::TwoD6 => 12,
            ValueExpr::TwoD6Plus(n) => 12 + n,
            ValueExpr::ThreeD6 => 18,
            ValueExpr::ThreeD6Plus(n) => 18 + n,
        }
    }

    pub fn expected_value(&self) -> f64 {
        match *self {
            ValueExpr::Flat(n) => n as f64,
            ValueExpr::D3 => 2.0,
            ValueExpr::D3Plus(n) => 2.0 + n as f64,
            ValueExpr::D6 => 3.5,
            ValueExpr::D6Plus(n) => 3.5 + n as f64,
            ValueExpr::TwoD6 => 7.0,
            ValueExpr::TwoD6Plus(n) => 7.0 + n as f64,
            ValueExpr::ThreeD6 => 10.5,
            ValueExpr::ThreeD6Plus(n) => 10.5 + n as f64,
        }
    }

    /// Returns the exact discrete probability mass function `(value, probability)` for this dice expression.
    pub fn pmf(&self) -> Vec<(u32, f64)> {
        match *self {
            ValueExpr::Flat(n) => vec![(n, 1.0)],
            ValueExpr::D3 => (1..=3).map(|v| (v, 1.0 / 3.0)).collect(),
            ValueExpr::D3Plus(n) => (1..=3).map(|v| (v + n, 1.0 / 3.0)).collect(),
            ValueExpr::D6 => (1..=6).map(|v| (v, 1.0 / 6.0)).collect(),
            ValueExpr::D6Plus(n) => (1..=6).map(|v| (v + n, 1.0 / 6.0)).collect(),
            ValueExpr::TwoD6 | ValueExpr::TwoD6Plus(_) => {
                let bonus = match *self {
                    ValueExpr::TwoD6Plus(n) => n,
                    _ => 0,
                };
                let mut counts = BTreeMap::new();
                for d1 in 1..=6 {
                    for d2 in 1..=6 {
                        *counts.entry(d1 + d2 + bonus).or_insert(0u32) += 1;
                    }
                }
                counts
                    .into_iter()
                    .map(|(val, c)| (val, c as f64 / 36.0))
                    .collect()
            }
            ValueExpr::ThreeD6 | ValueExpr::ThreeD6Plus(_) => {
                let bonus = match *self {
                    ValueExpr::ThreeD6Plus(n) => n,
                    _ => 0,
                };
                let mut counts = BTreeMap::new();
                for d1 in 1..=6 {
                    for d2 in 1..=6 {
                        for d3 in 1..=6 {
                            *counts.entry(d1 + d2 + d3 + bonus).or_insert(0u32) += 1;
                        }
                    }
                }
                counts
                    .into_iter()
                    .map(|(val, c)| (val, c as f64 / 216.0))
                    .collect()
            }
        }
    }
}

impl fmt::Display for ValueExpr {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ValueExpr::Flat(n) => write!(f, "{}", n),
            ValueExpr::D3 => write!(f, "D3"),
            ValueExpr::D3Plus(n) => write!(f, "D3+{}", n),
            ValueExpr::D6 => write!(f, "D6"),
            ValueExpr::D6Plus(n) => write!(f, "D6+{}", n),
            ValueExpr::TwoD6 => write!(f, "2D6"),
            ValueExpr::TwoD6Plus(n) => write!(f, "2D6+{}", n),
            ValueExpr::ThreeD6 => write!(f, "3D6"),
            ValueExpr::ThreeD6Plus(n) => write!(f, "3D6+{}", n),
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

        match cleaned.as_str() {
            "D3" | "1D3" => return Ok(ValueExpr::D3),
            "D6" | "1D6" => return Ok(ValueExpr::D6),
            "2D6" => return Ok(ValueExpr::TwoD6),
            "3D6" => return Ok(ValueExpr::ThreeD6),
            _ => {}
        }

        if let Some(rest) = cleaned
            .strip_prefix("D3+")
            .or_else(|| cleaned.strip_prefix("1D3+"))
        {
            if let Ok(bonus) = rest.parse::<u32>() {
                return Ok(if bonus == 0 {
                    ValueExpr::D3
                } else {
                    ValueExpr::D3Plus(bonus)
                });
            }
        }

        if let Some(rest) = cleaned
            .strip_prefix("D6+")
            .or_else(|| cleaned.strip_prefix("1D6+"))
        {
            if let Ok(bonus) = rest.parse::<u32>() {
                return Ok(if bonus == 0 {
                    ValueExpr::D6
                } else {
                    ValueExpr::D6Plus(bonus)
                });
            }
        }

        if let Some(rest) = cleaned.strip_prefix("2D6+") {
            if let Ok(bonus) = rest.parse::<u32>() {
                return Ok(if bonus == 0 {
                    ValueExpr::TwoD6
                } else {
                    ValueExpr::TwoD6Plus(bonus)
                });
            }
        }

        if let Some(rest) = cleaned.strip_prefix("3D6+") {
            if let Ok(bonus) = rest.parse::<u32>() {
                return Ok(if bonus == 0 {
                    ValueExpr::ThreeD6
                } else {
                    ValueExpr::ThreeD6Plus(bonus)
                });
            }
        }

        Err(ParseDiceError(s.to_string()))
    }
}
