//! Page structure

/// Page ID type
pub type PageId = u64;

/// In-memory page
#[repr(align(4096))]
pub struct Page {
    /// Page identifier
    pub id: PageId,
    /// Page data
    pub data: [u8; 4096],
}

impl Page {
    /// Create a new page
    pub fn new(id: PageId) -> Self {
        Self {
            id,
            data: [0; 4096],
        }
    }
}
