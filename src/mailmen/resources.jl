# Mailmen – model-specific resources

mutable struct MailmenStats
    total_dist::Float64
    num_remaining::Int
end
MailmenStats() = MailmenStats(0.0, 0)

# Lookup tables linking entities to indices for carrier tracking
mutable struct MailmenRegistry
    mailman_entities::Vector{Entity}
    letter_entities::Vector{Entity}
end
MailmenRegistry() = MailmenRegistry(Entity[], Entity[])
