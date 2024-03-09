# optimize-images Extension For Quarto

Optimizes images in quarto-based documents using `libvips` to save bandwidth.

## Installing

This library requires [`libvips`](https://www.libvips.org/) to be in your path. See their [installation instructions](https://www.libvips.org/install.html) to install it on your local machine.

Then,
```bash
quarto add abhiaagarwal/optimize-images
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.

## Using

This extension works by walking the Quarto AST of every single element and when it encounters an image, uses `libvips` to generate webp optimized images that will be served on your browser. It also generates multiple copies to be used with [responsive images](https://web.dev/articles/serve-responsive-images), serving images appropriate for your reader's device.

Thus, you are able to keep your original images in source control while your website deploys optimized copies.

TODO: Add Caching

## Example

Here is the source code for a minimal example: [example.qmd](example.qmd).
