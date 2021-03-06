#'@title Render Movie
#'
#'@description Renders a movie using the \pkg{av} package. Moves the camera around a 3D visualization 
#'using either a standard orbit, or accepts vectors listing user-defined values for each camera parameter. If the latter,
#'the values must be equal in length to `frames` (or of length `1`, in which the value will be fixed).
#'
#'@param filename Filename. If not appended with `.mp4`, it will be appended automatically.
#'@param type Default `orbit`, which orbits the 3D object at the user-set camera settings `phi`, `zoom`, and `fov`. 
#'Other options are `oscillate` (sine wave around `theta` value, covering 90 degrees), or `custom` (which uses the values from the 
#'`theta`, `phi`, `zoom`, and `fov` vectors passed in by the user).
#'@param frames Default `360`. Number of frames to render.
#'@param fps Default `30`. Frames per second. Recommmend either 30 or 60 for web.
#'@param phi Default `30`. Azimuth values, in degrees. 
#'@param theta Default `0`. Theta values, in degrees. 
#'@param zoom Defaults to the current view. Zoom value, between `0` and `1`. 
#'@param fov Defaults to the current view. Field of view values, in degrees.
#'@param title_text Default `NULL`. Text. Adds a title to the movie, using magick::image_annotate. 
#'@param title_offset Default `c(20,20)`. Distance from the top-left (default, `gravity` direction in 
#'image_annotate) corner to offset the title.
#'@param title_size Default `30`. Font size in pixels.
#'@param title_color Default `black`. Font color.
#'@param title_font Default `sans`. String with font family such as "sans", "mono", "serif", "Times", "Helvetica", 
#'"Trebuchet", "Georgia", "Palatino" or "Comic Sans".
#'@param image_overlay Default `NULL`. Either a string indicating the location of a png image to overlay
#'over the whole movie (transparency included), or a 4-layer RGBA array. This image will be resized to the 
#'dimension of the movie if it does not match exactly.
#'@param audio Default `NULL`. Optional file with audio to add to the video.
#'@param progbar Default `TRUE` if interactive, `FALSE` otherwise. If `FALSE`, turns off progress bar. 
#'Will display a progress bar when adding an overlay or title.
#'@param ... Additional parameters to pass to magick::image_annotate. 
#'@export
#'@examples
#'filename_movie = tempfile()
#'
#'#By default, the function produces a 12 second orbit at 30 frames per second, at 30 degrees azimuth.
#'\donttest{
#'montereybay %>%
#'  sphere_shade(texture="imhof1") %>%
#'  plot_3d(montereybay, zscale=50, water = TRUE, watercolor="imhof1", 
#'          waterlinecolor="white", waterlinealpha=0.5)
#'#Un-comment the following to run:
#'#render_movie(filename = filename_movie)
#'}    
#'filename_movie = tempfile()
#'
#'#You can change to an oscillating orbit. The magnification is increased and azimuth angle set to 30.
#'#A title has also been added using the title_text argument.
#'\donttest{
#'montereybay %>%
#'  sphere_shade(texture="imhof1") %>%
#'  plot_3d(montereybay, zscale=50, water = TRUE, watercolor="imhof1", 
#'          waterlinecolor="white", waterlinealpha=0.5)
#'#Un-comment the following to run:
#'#render_movie(filename = filename_movie, type = "oscillate", 
#'#             frames = 60,  phi = 30, zoom = 0.8, theta = -90,
#'#             title_text = "Monterey Bay: Oscillating")
#'}             
#'filename_movie = tempfile()
#'
#'#Finally, you can pass your own set of values to the 
#'#camera parameters as a vector with type = "custom".
#'
#'phivechalf = 30 + 60 * 1/(1 + exp(seq(-7, 20, length.out = 180)/2))
#'phivecfull = c(phivechalf, rev(phivechalf))
#'thetavec = -90 + 60 * sin(seq(0,359,length.out = 360) * pi/180)
#'zoomvec = 0.45 + 0.2 * 1/(1 + exp(seq(-5, 20, length.out = 180)))
#'zoomvecfull = c(zoomvec, rev(zoomvec))
#'\donttest{
#'montereybay %>%
#'  sphere_shade(texture="imhof1") %>%
#'  plot_3d(montereybay, zscale=50, water = TRUE, watercolor="imhof1", 
#'          waterlinecolor="white", waterlinealpha=0.5)
#'#Un-comment the following to run
#'#render_movie(filename = filename_movie, type = "custom", 
#'#             frames = 360,  phi = phivecfull, zoom = zoomvecfull, theta = thetavec)
#'}
render_movie = function(filename, type = "orbit", frames = 360, fps = 30, 
                        phi = 30, theta = 0, zoom = NULL, fov = NULL, 
                        title_text = NULL, title_offset = c(20,20), 
                        title_color = "black", title_size = 30, title_font = "sans",
                        image_overlay = NULL, audio=NULL, progbar = interactive(), ...) {
  if(!("av" %in% rownames(utils::installed.packages()))) {
    stop("`av` package required for render_movie()")
  }
  if(is.null(filename)) {
    stop("render_movie requires a filename")
  }
  if(!is.null(title_text)) {
    has_title = TRUE
  } else {
    has_title = FALSE
  }
  if(length(title_offset) != 2) {
    stop("`title_offset` needs to be length-2 vector")
  }
  if(!is.null(image_overlay)) {
    if("character" %in% class(image_overlay)) {
      image_overlay_file = image_overlay
      has_overlay = TRUE
    } else if("array" %in% class(image_overlay)) {
      image_overlay_file = tempfile()
      png::writePNG(image_overlay_file)
      has_overlay = TRUE
    }
  } else {
    has_overlay = FALSE
  }
  if(substring(filename, nchar(filename)-3,nchar(filename)) != ".mp4") {
    filename = paste0(filename,".mp4")
  }
  windowsize = rgl::par3d()$viewport
  if(is.null(fov)) {
    fov = rgl::par3d()$FOV
  }
  if(is.null(zoom)) {
    zoom = rgl::par3d()$zoom
  }
  png_files = file.path(tempdir(), sprintf("image%d.png", seq_len(frames)))
  on.exit(unlink(png_files))
  if(type == "orbit") {
    theta_vector = seq(0,360,length.out = frames+1)[-(frames+1)]
    for(i in seq_len(frames)) {
      render_camera(theta = theta_vector[i], phi = phi, zoom = zoom, fov = fov)
      rgl::snapshot3d(filename = png_files[i])
    }
  } else if (type == "oscillate") {
    theta_vector = theta + 45 * sin(seq(0,360,length.out = frames+1)[-(frames+1)]*pi/180)
    for(i in seq_len(frames)) {
      render_camera(theta = theta_vector[i], phi = phi, zoom = zoom, fov = fov)
      rgl::snapshot3d(filename = png_files[i])
    }
  } else if (type == "custom") {
    if(length(theta) == 1) theta = rep(theta, frames)
    if(length(phi) == 1) phi = rep(phi, frames)
    if(length(zoom) == 1) zoom = rep(zoom, frames)
    if(length(fov) == 1) fov = rep(fov, frames)
    if(!all(c(length(theta), length(phi), length(zoom),length(fov)) == frames)) {
      stop("All camera vectors must be the same length (or fixed values)")
    }
    for(i in seq_len(frames)) {
      render_camera(theta = theta[i], phi = phi[i], zoom = zoom[i], fov = fov[i])
      rgl::snapshot3d(filename = png_files[i])
    }
  } else {
    stop("Unknown type: ", type)
  }
  temp = png::readPNG(png_files[1])
  dimensions = dim(temp)
  if(dimensions[1] %% 2 != 0) {
    dimensions[1] = dimensions[1] - 1
  }
  if(has_overlay) {
    if(!("magick" %in% rownames(utils::installed.packages()))) {
      stop("`magick` package required for adding overlay")
    }
    if(progbar) {
      pb = progress::progress_bar$new(
        format = "  Adding overlay image [:bar] :percent eta: :eta",
        total = frames, width= 60)
    }
    for(i in seq_len(frames)) {
      if(progbar) {
        pb$tick()
      }
      magick::image_read(png_files[i]) %>%
        magick::image_composite(
          magick::image_scale(magick::image_read(image_overlay_file),
                      paste0(dimensions[1],"x",dimensions[2]))
          ) %>%
        magick::image_write(path = png_files[i], format = "png")
    }
  }
  if(has_title) {
    if(!("magick" %in% rownames(utils::installed.packages()))) {
      stop("`magick` package required for adding title")
    }
    if(progbar) {
      pb = progress::progress_bar$new(
        format = "  Adding title text [:bar] :percent eta: :eta",
        total = frames, width= 60)
    }
    for(i in seq_len(frames)) {
      if(progbar) {
        pb$tick()
      }
      magick::image_read(png_files[i]) %>%
        magick::image_annotate(title_text, 
                       location = paste0("+", title_offset[1],"+",title_offset[2]),
                       size = title_size, color = title_color, 
                       font = title_font, ...) %>%
        magick::image_write(path = png_files[i], format = "png")
    }
  }
  av::av_encode_video(png_files, output = filename, framerate = fps, 
                      vfilter = paste0("scale=",dimensions[1],":-2"), audio=audio)
}
