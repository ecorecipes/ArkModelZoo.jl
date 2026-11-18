using Documenter, ArkModelZoo

# Headless plotting, in case a docstring example plots (GR).
ENV["GKSwstype"] = "100"

const DOCS = @__DIR__
const ROOT = normpath(joinpath(DOCS, ".."))
const VIG = joinpath(ROOT, "vignettes")
const OUT = joinpath(DOCS, "src", "tutorials")

# Quarto's GitHub-flavoured Markdown, made readable by Documenter:
# - its table of contents (and the author line) is dropped, since Documenter shows its own;
# - `<img src=... alt=... />` becomes a Markdown image, so Documenter rewrites its path;
# - HTML comments are dropped;
# - any other raw HTML block (tables from the NetLogo info tabs) becomes an `@raw html` block,
#   because Documenter escapes raw HTML in Markdown.
# Code fences are left alone.
function documenter_markdown(text::AbstractString)
    text = replace(text, r"\A(# [^\n]*\n)(?:[^\n#-][^\n]*\n)?\s*(?:[ \t]*- \[[^\n]*\n(?:[ \t]+[^\n]*\n)*)+"s => s"\1\n")
    text = replace(text, r"<!--.*?-->"s => "")
    text = replace(text, r"<img\s+src=\"([^\"]+)\"[^>]*?(?:alt=\"([^\"]*)\")?[^>]*/>"s =>
                             s -> (m = match(r"src=\"([^\"]+)\"", s); a = match(r"alt=\"([^\"]*)\"", s);
                                   "![" * (a === nothing ? "" : a.captures[1]) * "](" * m.captures[1] * ")"))
    out = IOBuffer()
    fence = ""
    html = String[]
    flush_html() = (isempty(html) || print(out, "```@raw html\n", join(html), "```\n"); empty!(html))
    for line in eachline(IOBuffer(text); keep = true)
        m = match(r"^[ \t]*(`{3,}|~{3,})", line)
        if !isempty(fence)
            print(out, line)
            m !== nothing && strip(line) == m.captures[1] && first(m.captures[1]) == first(fence) &&
                (fence = "")
        elseif m !== nothing
            flush_html()
            fence = m.captures[1]
            print(out, line)
        elseif !isempty(html) && !isempty(strip(line))
            push!(html, line)
        elseif startswith(lstrip(line), "<") && occursin(r"^\s*</?[A-Za-z]", line)
            push!(html, line)
        else
            flush_html()
            print(out, line)
        end
    end
    flush_html()
    return String(take!(out))
end

# Each vignette keeps its own folder, because every model names its figures plot_*.png.
function sync_tutorials()
    rm(OUT; recursive = true, force = true)
    pages = Pair{String,String}[]
    for d in sort(readdir(VIG))
        src = joinpath(VIG, d, d * ".md")
        isfile(src) || continue
        dst = joinpath(OUT, d)
        mkpath(dst)
        text = documenter_markdown(read(src, String))
        write(joinpath(dst, d * ".md"), text)
        for f in readdir(joinpath(VIG, d))
            any(endswith(f, e) for e in (".png", ".svg", ".jpg", ".gif")) && cp(joinpath(VIG, d, f), joinpath(dst, f))
        end
        files = joinpath(VIG, d, d * "_files")
        if isdir(files)
            for (root, _, fs) in walkdir(files), f in fs
                occursin("/libs", root) && continue
                rel = relpath(joinpath(root, f), joinpath(VIG, d))
                mkpath(dirname(joinpath(dst, rel)))
                cp(joinpath(root, f), joinpath(dst, rel))
            end
        end
        m = match(r"^# (.+)$"m, text)
        push!(pages, (m === nothing ? d : strip(m.captures[1])) => "tutorials/$d/$d.md")
    end
    return pages
end

# The home page is the README.
write(joinpath(DOCS, "src", "index.md"), read(joinpath(ROOT, "README.md"), String))

tutorials = sync_tutorials()
resilience = filter(p -> occursin("/resilience/", last(p)), tutorials)
models = sort(filter(p -> !occursin("/resilience/", last(p)), tutorials); by = p -> lowercase(first(p)))

makedocs(;
    modules = [ArkModelZoo],
    warnonly = true,
    checkdocs = :none,
    authors = "Simon Frost",
    sitename = "ArkModelZoo.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://ecorecipes.github.io/ArkModelZoo.jl",
        size_threshold = 1024 * 1024,
        size_threshold_warn = 512 * 1024,
    ),
    pages = [
        "Home" => "index.md",
        "Resilience" => resilience,
        "Models" => models,
        "API Reference" => "api.md",
    ],
)

deploydocs(;
    repo = "github.com/ecorecipes/ArkModelZoo.jl.git",
    push_preview = true,
)
