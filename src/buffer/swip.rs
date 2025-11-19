//! Swizzled pointer (hot or cold)

use super::Page;

/// Swizzled pointer - the key innovation of LeanStore
pub enum Swip {
    /// Hot: Direct pointer to in-memory page (O(1) access)
    Hot(*mut Page),
    /// Cold: Disk offset (requires I/O to load)
    Cold(u64),
}

impl Swip {
    /// Create a cold (on-disk) swip
    pub fn cold(offset: u64) -> Self {
        Swip::Cold(offset)
    }

    /// Create a hot (in-memory) swip
    pub fn hot(ptr: *mut Page) -> Self {
        Swip::Hot(ptr)
    }

    /// Check if this is a hot pointer
    pub fn is_hot(&self) -> bool {
        matches!(self, Swip::Hot(_))
    }

    /// Check if this is a cold pointer
    pub fn is_cold(&self) -> bool {
        matches!(self, Swip::Cold(_))
    }
}
