-- Compatibility alias for early callers. New code uses tagpax-native directly;
-- forwarding avoids a second implementation.
return require("tagpax-native")
