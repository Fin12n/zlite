//! Product Catalog and Price Quote Cards (#STT 6.3).
//!
//! Provides catalog management, formatted VND currency displays,
//! and parsing/rendering of structured product quote cards within chat bubbles.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProductItem {
    pub id: String,
    pub name: String,
    pub price: u64,
    pub image_url: String,
    pub description: String,
    pub sku: String,
}

impl ProductItem {
    pub fn new(name: impl Into<String>, price: u64, sku: impl Into<String>, description: impl Into<String>, image_url: impl Into<String>) -> Self {
        let name_str = name.into();
        let id = format!("prod_{}_{}", crate::crypto::md5_hex(&name_str), price);
        Self {
            id,
            name: name_str,
            price,
            image_url: image_url.into(),
            description: description.into(),
            sku: sku.into(),
        }
    }

    /// Formats the item as a structured chat message for Zalo.
    pub fn to_quote_message(&self) -> String {
        let price_vnd = format_currency_vnd(self.price);
        format!(
            "[Sản phẩm] {} | Giá: {} | SKU: {} | {}",
            self.name.trim(),
            price_vnd,
            self.sku.trim(),
            self.description.trim()
        )
    }

    /// Attempts to parse a product item from a formatted chat message.
    pub fn from_message_text(text: &str, link_thumb: Option<&str>) -> Option<Self> {
        let trimmed = text.trim();
        if !trimmed.starts_with("[Sản phẩm]") && !trimmed.starts_with("[Báo giá]") {
            return None;
        }

        let content = trimmed
            .trim_start_matches("[Sản phẩm]")
            .trim_start_matches("[Báo giá]")
            .trim();

        let parts: Vec<&str> = content.split('|').map(str::trim).collect();
        if parts.is_empty() {
            return None;
        }

        let name = parts[0].to_string();
        if name.is_empty() {
            return None;
        }

        let mut price = 0u64;
        let mut sku = String::new();
        let mut description = String::new();

        for part in &parts[1..] {
            if let Some(val) = part.strip_prefix("Giá:") {
                let clean_digits: String = val.chars().filter(|c| c.is_ascii_digit()).collect();
                price = clean_digits.parse::<u64>().unwrap_or(0);
            } else if let Some(val) = part.strip_prefix("SKU:") {
                sku = val.trim().to_string();
            } else if description.is_empty() {
                description = part.to_string();
            }
        }

        let image_url = link_thumb.unwrap_or("").to_string();
        let id = format!("parsed_{}_{}", crate::crypto::md5_hex(&name), price);

        Some(Self {
            id,
            name,
            price,
            image_url,
            description,
            sku,
        })
    }
}

/// Formats an unsigned integer amount into VND currency string (e.g. `150.000 ₫`).
pub fn format_currency_vnd(amount: u64) -> String {
    let s = amount.to_string();
    let mut result = String::new();
    let mut count = 0;
    for c in s.chars().rev() {
        if count > 0 && count % 3 == 0 {
            result.push('.');
        }
        result.push(c);
        count += 1;
    }
    let formatted: String = result.chars().rev().collect();
    format!("{formatted} ₫")
}

/// Returns default sample catalog items for quick business messaging demo.
pub fn default_sample_catalog() -> Vec<ProductItem> {
    vec![
        ProductItem::new(
            "Cà phê Arabica Cầu Đất (Gói 500g)",
            165000,
            "CF-ARA-500",
            "Cà phê nguyên chất rang mộc hương thơm nồng nàn, hậu vị ngọt sâu.",
            "https://stc-zaloprofile.zdn.vn/images/default_product.png",
        ),
        ProductItem::new(
            "Trà Ô Long Thượng Hạng (Hộp 250g)",
            220000,
            "TEA-OLO-250",
            "Búp trà ô long tuyển chọn từ cao nguyên Mộc Châu, hương thơm thanh khiết.",
            "https://stc-zaloprofile.zdn.vn/images/default_product.png",
        ),
        ProductItem::new(
            "Hạt Điều Rang Muối Bình Phước (Hũ 500g)",
            145000,
            "CASHEW-BP-500",
            "Hạt điều loại 1 giòn rụm, béo ngậy, ít muối đậm đà dinh dưỡng.",
            "https://stc-zaloprofile.zdn.vn/images/default_product.png",
        ),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_format_currency_vnd() {
        assert_eq!(format_currency_vnd(0), "0 ₫");
        assert_eq!(format_currency_vnd(500), "500 ₫");
        assert_eq!(format_currency_vnd(1000), "1.000 ₫");
        assert_eq!(format_currency_vnd(250000), "250.000 ₫");
        assert_eq!(format_currency_vnd(12500000), "12.500.000 ₫");
    }

    #[test]
    fn test_product_quote_roundtrip() {
        let item = ProductItem::new("Tai nghe không dây Pro", 450000, "TWS-PRO-01", "Chống ồn chủ động ANC", "");
        let msg = item.to_quote_message();
        assert!(msg.starts_with("[Sản phẩm]"));
        assert!(msg.contains("Tai nghe không dây Pro"));
        assert!(msg.contains("450.000 ₫"));

        let parsed = ProductItem::from_message_text(&msg, Some("https://example.com/thumb.jpg")).expect("parse product");
        assert_eq!(parsed.name, "Tai nghe không dây Pro");
        assert_eq!(parsed.price, 450000);
        assert_eq!(parsed.sku, "TWS-PRO-01");
        assert_eq!(parsed.description, "Chống ồn chủ động ANC");
        assert_eq!(parsed.image_url, "https://example.com/thumb.jpg");
    }
}
