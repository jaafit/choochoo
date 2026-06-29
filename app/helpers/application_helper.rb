module ApplicationHelper
  # Tailwind classes styling a player's name. Colour marks the role — teal
  # #15786A for admins, ink #33271A for everyone else — and "me" (the signed-in
  # player) is shown in italics on top of whichever colour applies.
  def player_name_classes(player, mine: nil)
    mine = (player.id == current_player&.id) if mine.nil?
    color = player.admin? ? "text-[#15786A]" : "text-[#33271A]"
    mine ? "#{color} italic" : color
  end

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
