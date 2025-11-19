use std::fmt;

/// Result type for qpdb operations
pub type Result<T> = std::result::Result<T, Error>;

/// Errors that can occur in qpdb
#[derive(Debug)]
pub enum Error {
    /// I/O error
    Io(std::io::Error),
    /// Database corruption
    Corruption(String),
    /// Key not found
    NotFound,
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Error::Io(e) => write!(f, "I/O error: {}", e),
            Error::Corruption(msg) => write!(f, "Database corruption: {}", msg),
            Error::NotFound => write!(f, "Key not found"),
        }
    }
}

impl std::error::Error for Error {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Error::Io(e) => Some(e),
            _ => None,
        }
    }
}

impl From<std::io::Error> for Error {
    fn from(err: std::io::Error) -> Self {
        Error::Io(err)
    }
}
