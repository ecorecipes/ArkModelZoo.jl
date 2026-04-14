# Position on the grid (patch coordinates)
mutable struct FirePosition
    x::Int
    y::Int
end
FirePosition() = FirePosition(0, 0)

# Tag component: active fire (NetLogo breed "fires")
struct FireTag end

# Tag component: fading ember (NetLogo breed "embers")
struct EmberTag end

# Ember color for fade-out (NetLogo color value, starts at 15.0 = red)
mutable struct EmberColor
    color::Float64
end
EmberColor() = EmberColor(15.0)
