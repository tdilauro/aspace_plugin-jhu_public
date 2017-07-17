## Summary

This plugin is currently targeted to ArchivesSpace 1.5.4 and implements Johns
Hopkins University Sheridan Libraries customizations to the ArchivesSpace public
user interface (PUI).

---

## Customizations

### Common elements (should be visible pretty much anywhere)

  - Branding
    - JHU Libraries logo
    - JHU Libraries site navigation
    - Style changes for consistency with other JHU Libraries UX guidelines and/or recommendations

  - Header navigation bar:
    - Contact Us link in upper right header (moved from footer b/c might be harder to notice on long pages)
    - Removed "Accessions", "Classifications", and "Digital Objects" links.

  - Footer:
    - Changed text from `Visit ArchivesSpace.org | <version>` to `Powered by ArchivesSpace <version>` and removed hyperlink to avoid end-user confusion.

### Home page:
- Since DOs link is gone, added some text and links to get visitors to some of
other key repositories (JScholarship, Levy, and JHU Data Archive).

### Record view:
- Left-hand in-page anchor navigation: Changed "Components" to "Collection Details"
- Changed "Components" section heading text to "Collection Details"
- Changed Component tabs, when visible, to "Collection Details" and "Search this Collection".

### Breadcrumb:
- Prefixed resource titles with call number/identifier.

### Search results:
- Added callno/identifier column to results
- Added column headings, since there are now two columns in the results
- Added responsive "show/hide facets/filters" to make use

---

## Activate the plugin
- Install the plugin:
  - Clone this repository into the plugins/jhu_public directory; or
  - Unzip the release zip into the plugins/jhu_public directory.

- Enable the plugin:
  - Edit the config/config.rb file to add the plugin name to the "AppConfig[:plugins]" list, e.g.:

    AppConfig[:plugins] = ['jhu_public']

- Restart ArchivesSpace
