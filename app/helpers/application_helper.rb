module ApplicationHelper
  # Inline, scalable SVG QR code for the given text.
  def qr_svg(text)
    RQRCode::QRCode.new(text).as_svg(
      module_size: 4,
      use_path: true,
      viewbox: true,
      svg_attributes: { class: "w-full h-auto" }
    ).html_safe
  end
end
