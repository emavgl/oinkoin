module Frameit
  module Devices
    SAMSUNG_GALAXY_S21_5G ||= Device.new(
      "samsung-galaxy-s21-5g",
      "Samsung Galaxy S21 5G",
      11,
      [[1080, 2400], [2400, 1080]],
      421,
      Color::BLACK,
      Platform::ANDROID
    )
  end

  FrameDownloader.send(:remove_const, :HOST_URL)
  FrameDownloader::HOST_URL = "https://raw.githubusercontent.com/emavgl/frameit-frames/gh-pages/"
end
