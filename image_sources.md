# Team image sources

The portraits in `static/images/team/` were collected from the public profile pages and image assets listed below. Local copies may have been cropped, resized, or re-encoded for consistent display on the Team page. These links document provenance; image ownership and copyright remain with the original sources and photographers.

Sources were verified on 2026-09-10.

## PIs

| Local file | Person | Source page | Original image asset |
| --- | --- | --- | --- |
| [`eric-jankowski.jpg`](static/images/team/eric-jankowski.jpg) | Eric Jankowski | [Boise State University profile](https://experts.boisestate.edu/en/persons/eric-jankowski/) | [Jankowski_Eric_website.jpg](https://experts.boisestate.edu/files-asset/7024815/Jankowski_Eric_website.jpg) |
| [`jacob-gissinger.jpg`](static/images/team/jacob-gissinger.jpg) | Jacob Gissinger | [Stevens Institute of Technology profile](https://www.stevens.edu/profile/jgissing) | [jgissing.jpg](https://images.ctfassets.net/mviowpldu823/AupmHzVdpJx1sVyBJYqMW/c5c50768a7a36ad583cebfbb647f156b/jgissing.jpg) |
| [`jeff-wagner.jpg`](static/images/team/jeff-wagner.jpg) | Jeff Wagner | [Open Force Field team page](https://openforcefield.org/about/team/) | [jeff-wagner.jpg](https://openforcefield.org/about/team/img/jeff-wagner.jpg) |
| [`janani-sampath.jpg`](static/images/team/janani-sampath.jpg) | Janani Sampath | [University of Florida profile](https://che.ufl.edu/research/modeling-theory-and-simulation/name/janani-sampath/) | [Sampath_2021.jpg](https://che.ufl.edu/wp-content/uploads/sites/47/connections-images/janani-sampath/Sampath_2021-110b0b88dc72f76719411cf4ed91b6f6.jpg) |
| [`sapna-sarupria.jpg`](static/images/team/sapna-sarupria.jpg) | Sapna Sarupria | [Sarupria Group people page](https://sampel-group.github.io/people.html) | [Sarupria_UMN.JPG](https://sampel-group.github.io/Data/Pictures/mugshots/Sarupria_UMN.JPG) |
| [`michael-shirts.jpg`](static/images/team/michael-shirts.jpg) | Michael Shirts | [University of Colorado Boulder profile](https://www.colorado.edu/certificate/iqbiology/michael-shirts) | [michael_shirts_.jpg](https://www.colorado.edu/certificate/iqbiology/sites/default/files/people/michael_shirts_.jpg) |

## Trainees

| Local file | Person | Source page | Original image asset |
| --- | --- | --- | --- |
| [`tim-bernat.jpg`](static/images/team/tim-bernat.jpg) | Tim Bernat | [GitHub profile](https://github.com/timbernat) | [GitHub avatar](https://github.com/timbernat.png?size=400) |
| [`salman-bin-kashif.jpg`](static/images/team/salman-bin-kashif.jpg) | Salman Bin Kashif | [Sarupria Group people page](https://sampel-group.github.io/people.html) | [Kashif.jpg](https://sampel-group.github.io/Data/Pictures/mugshots/Kashif.jpg) |
| [`sirsha-ganguly.jpg`](static/images/team/sirsha-ganguly.jpg) | Sirsha Ganguly | [University of Florida profile](https://che.ufl.edu/people/ph-d-students/name/sirsha-ganguly/) | [Ganguly-Sirsha_4-web.jpg](https://che.ufl.edu/wp-content/uploads/sites/47/connections-images/sirsha-ganguly/Ganguly-Sirsha_4-web-cfe72ec0789881a539ad9704e6d2f5d2.jpg) |
| [`joe-laforet-jr.jpg`](static/images/team/joe-laforet-jr.jpg) | Joe Laforet Jr. | [GitHub profile](https://github.com/joelaforet) | [GitHub avatar](https://github.com/joelaforet.png?size=400) |
| [`janitha-mahanthe.jpg`](static/images/team/janitha-mahanthe.jpg) | Janitha Mahanthe | [Google Scholar profile](https://scholar.google.com/citations?user=pKk3dVUAAAAJ) | [Google Scholar profile photo](https://scholar.googleusercontent.com/citations?view_op=view_photo&user=pKk3dVUAAAAJ&citpid=1)² |
| [`stephanie-mccallum.jpg`](static/images/team/stephanie-mccallum.jpg) | Stephanie McCallum | [GitHub profile](https://github.com/StephMcCallum) | [GitHub avatar](https://github.com/StephMcCallum.png?size=400) |
| [`naomi-trampe.jpg`](static/images/team/naomi-trampe.jpg) | Naomi Trampe | [Sarupria Group people page](https://sampel-group.github.io/people.html) | [Trampe.jpeg](https://sampel-group.github.io/Data/Pictures/mugshots/Trampe.jpeg) |

## Support Staff

| Local file | Person | Source page | Original image asset |
| --- | --- | --- | --- |
| [`david-swenson.jpg`](static/images/team/david-swenson.jpg) | David W. H. Swenson | [GitHub profile](https://github.com/dwhswenson) | [GitHub avatar](https://github.com/dwhswenson.png?size=400) |
| [`ennea-fairchild-grant.webp`](static/images/team/ennea-fairchild-grant.webp) | Ennea Fairchild-Grant | [Atlas of Drowned Towns team](https://www.drownedtowns.com/learn/team/) | [about-ennea-cropped.jpg](https://www.drownedtowns.com/images/about-ennea-cropped.jpg)¹ |

¹ Ennea Fairchild-Grant's portrait is credited to Torin Alm on the source page.

² The local Janitha Mahanthe image is a higher-resolution copy of the same portrait shown on the linked Google Scholar profile. The exact high-resolution upstream asset URL was not retained; Google Scholar currently exposes the linked 128-pixel derivative.

GitHub avatar URLs are mutable and will return the account's current avatar if it is changed later.

## Image checks and optimization

Team portraits render as square, 400-pixel-wide sources. Keep the subject near
the center because the page uses `object-fit: cover` to crop non-square images.

Run the same validation used in CI:

```console
pixi run check-team-images
```

The check warns when an image's shorter edge is below 400 pixels and may look
blurry. It fails when the longer edge exceeds 800 pixels. Reduce oversized
images in place with:

```console
pixi run optimize-team-images
```

Optimization preserves aspect ratio, applies EXIF orientation, strips metadata,
and limits the longer edge to 800 pixels. The Python runtime and Pillow are
installed from conda-forge by Pixi; no separate Python environment is needed.
