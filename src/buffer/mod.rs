//! Buffer pool management with pointer swizzling

mod page;
mod swip;

pub use page::{Page, PageId};
pub use swip::Swip;
