// needed for callout support
#import "@preview/fontawesome:0.1.0": *

// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw: it => {
  if it.block {
    block(fill: luma(230), width: 100%, inset: 8pt, radius: 2pt, it)
  } else {
    it
  }
}

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

#show figure: it => {
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match != none {
    let kind = kind_match.captures.at(0, default: "other")
    kind = upper(kind.first()) + kind.slice(1)
    // now we pull apart the callout and reassemble it with the crossref name and counter

    // when we cleanup pandoc's emitted code to avoid spaces this will have to change
    let old_callout = it.body.children.at(1).body.children.at(1)
    let old_title_block = old_callout.body.children.at(0)
    let old_title = old_title_block.body.body.children.at(2)

    // TODO use custom separator if available
    let new_title = if empty(old_title) {
      [#kind #it.counter.display()]
    } else {
      [#kind #it.counter.display(): #old_title]
    }

    let new_title_block = block_with_new_content(
      old_title_block, 
      block_with_new_content(
        old_title_block.body, 
        old_title_block.body.body.children.at(0) +
        old_title_block.body.body.children.at(1) +
        new_title))

    block_with_new_content(old_callout,
      new_title_block +
      old_callout.body.children.at(1))
  } else {
    it
  }
}

#show ref: it => locate(loc => {
  let target = query(it.target, loc).first()
  if it.at("supplement", default: none) == none {
    it
    return
  }

  let sup = it.supplement.text.matches(regex("^45127368-afa1-446a-820f-fc64c546b2c5%(.*)")).at(0, default: none)
  if sup != none {
    let parent_id = sup.captures.first()
    let parent_figure = query(label(parent_id), loc).first()
    let parent_location = parent_figure.location()

    let counters = numbering(
      parent_figure.at("numbering"), 
      ..parent_figure.at("counter").at(parent_location))
      
    let subcounter = numbering(
      target.at("numbering"),
      ..target.at("counter").at(target.location()))
    
    // NOTE there's a nonbreaking space in the block below
    link(target.location(), [#parent_figure.at("supplement") #counters#subcounter])
  } else {
    it
  }
})

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      block(
        inset: 1pt, 
        width: 100%, 
        block(fill: white, width: 100%, inset: 8pt, body)))
}



#let article(
  title: none,
  authors: none,
  date: none,
  abstract: none,
  cols: 1,
  margin: (x: 1.25in, y: 1.25in),
  paper: "us-letter",
  lang: "en",
  region: "US",
  font: (),
  fontsize: 11pt,
  sectionnumbering: none,
  toc: false,
  doc,
) = {
  set page(
    paper: paper,
    margin: margin,
    numbering: "1",
  )
  set par(justify: true)
  set text(lang: lang,
           region: region,
           font: font,
           size: fontsize)
  set heading(numbering: sectionnumbering)

  if title != none {
    align(center)[#block(inset: 2em)[
      #text(weight: "bold", size: 1.5em)[#title]
    ]]
  }

  if authors != none {
    let count = authors.len()
    let ncols = calc.min(count, 3)
    grid(
      columns: (1fr,) * ncols,
      row-gutter: 1.5em,
      ..authors.map(author =>
          align(center)[
            #author.name \
            #author.affiliation \
            #author.email
          ]
      )
    )
  }

  if date != none {
    align(center)[#block(inset: 1em)[
      #date
    ]]
  }

  if abstract != none {
    block(inset: 2em)[
    #text(weight: "semibold")[Abstract] #h(1em) #abstract
    ]
  }

  if toc {
    block(above: 0em, below: 2em)[
    #outline(
      title: auto,
      depth: none
    );
    ]
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}
#show: doc => article(
  title: [Rogue Scholar Digest November 15, 2023],
  authors: (
    ( name: [Martin Fenner],
      affiliation: [Front Matter],
      email: [] ),
    ),
  date: [2023-11-15],
  cols: 1,
  doc,
)


#block[
#block[
```python
import requests
import locale
import re
from typing import Optional
import datetime
from IPython.display import Markdown
locale.setlocale(locale.LC_ALL, "en_US")
baseUrl = "https://api.rogue-scholar.org/"
include_fields = "title,authors,published_at,summary,blog_name,blog_slug,doi,url,image"
url = baseUrl + f"posts?&published_since={published_since}&published_until={published_until}&language=en&sort=published_at&order=asc&per_page=50&include_fields={include_fields}"
response = requests.get(url)
result = response.json()

def get_post(post):
    return post["document"]

def format_post(post):
    url = post.get("doi", None)
    url = f"[{url}]({url})\n<br />" if url else ""
    title = f"[{post['title']}]({url})"
    published_at = datetime.datetime.utcfromtimestamp(post["published_at"]).strftime("%B %-d, %Y")
    blog = f"[{post['blog_name']}](https://rogue-scholar.org/blogs/{post['blog_slug']})"
    author = ", ".join([ f"{x['name']}" for x in post.get("authors", None) or [] ])
    summary = post["summary"]
    return f"### {title}\n{url}Published {published_at} in {blog}<br />{author}<br /><br />{summary}\n"

posts = [ get_post(x) for i, x in enumerate(result["hits"]) ]
posts_as_string = "\n".join([ format_post(x) for x in posts])

def doi_from_url(url: str) -> Optional[str]:
    """Return a DOI from a URL"""
    match = re.search(
        r"\A(?:(http|https)://(dx\.)?(doi\.org|handle\.stage\.datacite\.org|handle\.test\.datacite\.org)/)?(doi:)?(10\.\d{4,5}/.+)\Z",
        url,
    )
    if match is None:
        return None
    return match.group(5).lower()

images = [ x["image"] for x in posts if x.get("image", None) is not None ]
image = images[featured_image]
markdown = f"![]({image})\n\n" + posts_as_string
Markdown(markdown)
```

#block[
#box(width: 2048.0pt, image("https://www.scholcommlab.ca/wp-content/uploads/2023/11/STI2023-group-photo.jpg"))

== #link("")[Introducing the CWTS ECR/PhD Council]
<introducing-the-cwts-ecrphd-council>
Published November 8, 2023 in #link("https://rogue-scholar.org/blogs/leidenmadtrics")[Leiden Madtrics]Leiden MadtricsIn this blog post, we’ll introduce you to the CWTS ECR/PhD Council, shedding light on its significance, objectives, and how it can serve as a crucial resource for early career researchers and PhDs at CWTS. CWTS is an interdisciplinary institute at Leiden University with a diverse multinational academic culture. PhD candidates, early career researchers, and visiting scholars from around the world gather at CWTS to pursue their research journeys.

== #link("%5Bhttps://doi.org/10.59350/ahnf6-e1m90%5D(https://doi.org/10.59350/ahnf6-e1m90)%20%3Cbr%20/%3E")[BioBanking at GGBN 2023: Highlights from GigaScience Press]
<biobanking-at-ggbn-2023-highlights-from-gigascience-press>
#link("https://doi.org/10.59350/ahnf6-e1m90") Published November 8, 2023 in #link("https://rogue-scholar.org/blogs/gigablog")[GigaBlog]Chris Armit "Extinction is forever – so our action must be immediate." – Sir David Attenborough, Sept 30th 2020 The fourth international Global Genome Biodiversity Network \(GGBN) Conference took place in Aguascalientes, Mexico from October 17th to October 20th 2023 where it was hosted by the Universidad Autónoma de Aguascalientes.

== #link("%5Bhttps://doi.org/10.59350/vbp1j-f9j63%5D(https://doi.org/10.59350/vbp1j-f9j63)%20%3Cbr%20/%3E")[From Ottawa to Leiden: ScholCommLab’s Conference Highlights]
<from-ottawa-to-leiden-scholcommlabs-conference-highlights>
#link("https://doi.org/10.59350/vbp1j-f9j63") Published November 9, 2023 in #link("https://rogue-scholar.org/blogs/scholcommlab")[Scholarly Communications Lab | ScholCommLab]Olivia AguiarOver the last few months, ScholCommLab members took part in over six conferences, including the: International Conference on Science, Technology, and Innovation Indicators \(STI 2023), International Communication Association Conference \(ICA 2023), and Bibliometrics and Research Impact Community Conference \(BRIC 2023). In this blog post, we’re sharing highlights from each event.

== #link("%5Bhttps://doi.org/10.53731/g60vh-3ng48%5D(https://doi.org/10.53731/g60vh-3ng48)%20%3Cbr%20/%3E")[Archiving Rogue Scholar blogs with the Internet Archive]
<archiving-rogue-scholar-blogs-with-the-internet-archive>
#link("https://doi.org/10.53731/g60vh-3ng48") Published November 9, 2023 in #link("https://rogue-scholar.org/blogs/front_matter")[Front Matter]Martin FennerBlogs participating in the Rogue Scholar science blog archive are now archived in the Internet Archive. Starting November 1st, Rogue Scholar is participating in the Internet Archive Archive-It service and all archived blogs can be found here.

== #link("%5Bhttps://doi.org/10.59350/e3wmw-qwx29%5D(https://doi.org/10.59350/e3wmw-qwx29)%20%3Cbr%20/%3E")[Two influential textbooks – “Mee” and “Mellor”.]
<two-influential-textbooks-mee-and-mellor.>
#link("https://doi.org/10.59350/e3wmw-qwx29") Published November 11, 2023 in #link("https://rogue-scholar.org/blogs/rzepa")[Henry Rzepa’s Blog]Henry RzepaI am a member of the ~Royal Society of ~Chemistry’s Historical group. Amongst other activities, it publishes two editions~of a newsletter each year for its members.

== #link("%5Bhttps://doi.org/10.59350/5hxdg-fz574%5D(https://doi.org/10.59350/5hxdg-fz574)%20%3Cbr%20/%3E")[Auto-DOI for Quarto posts via Rogue Scholar]
<auto-doi-for-quarto-posts-via-rogue-scholar>
#link("https://doi.org/10.59350/5hxdg-fz574") Published November 13, 2023 in #link("https://rogue-scholar.org/blogs/chrisvoncsefalvay")[Chris von Csefalvay]Chris von CsefalvayI love posts that allow me to merge some of my addictions.

== #link("%5Bhttps://doi.org/10.59350/6vjpn-ky077%5D(https://doi.org/10.59350/6vjpn-ky077)%20%3Cbr%20/%3E")[Data on 100 million individual trees in the National Ecological Observatory Network]
<data-on-100-million-individual-trees-in-the-national-ecological-observatory-network>
#link("https://doi.org/10.59350/6vjpn-ky077") Published November 13, 2023 in #link("https://rogue-scholar.org/blogs/jabberwocky_ecology")[Jabberwocky Ecology]Ethan WhiteWe’re excited to announce the initial release of crown maps for 100 million trees in the National Ecological Observatory Network \(NEON) with information on location, species identify, size, and alive/dead status.

== #link("")[Do you dare? What female scientists expect when communicating]
<do-you-dare-what-female-scientists-expect-when-communicating>
Published November 14, 2023 in #link("https://rogue-scholar.org/blogs/elephantinthelab")[Elephant in the Lab]Sascha Schönig The expectation to communicate In 2019, the German Federal Ministry of Education and Research called for a cultural shift toward communicating science \(Bundesministerium für Bildung und Forschung, 2019). The former Federal Minister of Education and Research, Anja Karliczek, urged scientists to communicate their research continuously and classified communication as a central task for universities and research organizations

== #link("%5Bhttps://doi.org/10.59350/z537h-xsd22%5D(https://doi.org/10.59350/z537h-xsd22)%20%3Cbr%20/%3E")[Reevaluating POSI: 2023 evolution]
<reevaluating-posi-2023-evolution>
#link("https://doi.org/10.59350/z537h-xsd22") Published November 14, 2023 in #link("https://rogue-scholar.org/blogs/libscie")[Liberate Science]Liberate ScienceIn 2022, we did our first self-evaluation according to the Principles of Open Scholarly Infrastructure \(POSI). In this blog, we take stock \~1 year later, based on POSI v1.1, and reevaluate how we’re doing and where there’s still room for improvement. Summary 💚 \= aligned; 💛 \= less aligned;

== #link("%5Bhttps://doi.org/10.59350/qxhxa-kac46%5D(https://doi.org/10.59350/qxhxa-kac46)%20%3Cbr%20/%3E")[Upstream reflections]
<upstream-reflections>
#link("https://doi.org/10.59350/qxhxa-kac46") Published November 14, 2023 in #link("https://rogue-scholar.org/blogs/chjh")[Chris Hartgerink]Chris HartgerinkRecently, I left the Upstream editorial team as a result of changing priorities.~ I figured it would be a good idea to reflect before I forget.

== #link("%5Bhttps://doi.org/10.59350/txkht-ewp95%5D(https://doi.org/10.59350/txkht-ewp95)%20%3Cbr%20/%3E")[New paper: theropod bite marks on Morrison sauropod bones]
<new-paper-theropod-bite-marks-on-morrison-sauropod-bones>
#link("https://doi.org/10.59350/txkht-ewp95") Published November 14, 2023 in #link("https://rogue-scholar.org/blogs/svpow")[Sauropod Vertebra Picture of the Week]Matt Wedel~ New paper out today in PeerJ: Lei R, Tschopp E, Hendrickx C, Wedel MJ, Norell M, Hone DWE. 2023. Bite and tooth marks on sauropod dinosaurs from the Morrison Formation. PeerJ 11:e16327 http:\/\/doi.org/10.7717/peerj.16327 This one had a long gestation.

== #link("%5Bhttps://doi.org/10.53731/ch2e1-1cm64%5D(https://doi.org/10.53731/ch2e1-1cm64)%20%3Cbr%20/%3E")[The programmable blog]
<the-programmable-blog>
#link("https://doi.org/10.53731/ch2e1-1cm64") Published November 14, 2023 in #link("https://rogue-scholar.org/blogs/front_matter")[Front Matter]Martin FennerToday I am relaunching the Syldavia Gazette blog on a new blogging platform, switching from Ghost to Quarto. This allows me to use Jupyter notebooks in the blog to help generate blog posts. The Syldavia Gazette \(the other blog I manage besides the Front Matter blog) description says The Syldavia Gazette is a newsletter highlighting interesting science stories from around the web.

] <query>
]
]



