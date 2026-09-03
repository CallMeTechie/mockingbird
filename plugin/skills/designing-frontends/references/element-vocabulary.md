# Element type vocabulary (closed)

`element.type` in the manifest must be one of:

| Type | Use for |
| - | - |
| `region` | A layout area with no interactive content of its own |
| `nav` | Navigation (tabs, sidebar, breadcrumbs) |
| `list` | A repeated collection of items, not tabular |
| `table` | A repeated collection with columns |
| `card` | A single bounded unit summarizing one entity |
| `form` | A group of fields submitted together |
| `field` | A single input |
| `action` | A button, link or menu item that does something |
| `toggle` | A binary/tri-state control (switch, checkbox) |
| `metric` | A single number or KPI |
| `text` | Static or templated text with no data binding |
| `media` | Image, icon, video, avatar |
| `status` | A badge/pill communicating state |
| `chart` | Any data visualization |
| `feedback` | Toast, banner, inline validation message |
| `empty` | A dedicated empty-state element |
| `overlay` | Modal, drawer, popover |

`screen.kind` must be one of: `page | dialog | panel | view | flow-step | shared`.

Both lists are closed on purpose: a free-text type field would let every
project invent its own vocabulary, and `/design-verify`'s stage mandates are
written against these exact words.
