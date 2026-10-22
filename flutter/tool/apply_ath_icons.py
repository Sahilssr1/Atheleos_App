"""Replaces Material/Cupertino icon references in lib/ with the website icon set (AthIcons)."""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

MATERIAL = {
    "checkBadgeSolid": "verified verified_rounded",
    "checkBadge": "verified_outlined new_releases_outlined",
    "shieldCheck": "verified_user_outlined shield_outlined privacy_tip_outlined shield",
    "xMark": "close close_rounded clear cancel",
    "xCircle": "cancel_outlined",
    "userSolid": "person person_rounded",
    "user": "person_outline person_outline_rounded account_circle_outlined",
    "userCircle": "account_circle",
    "share": "share_outlined share_rounded share",
    "search": "search search_outlined search_rounded",
    "check": "check check_rounded",
    "heartFill": "favorite favorite_rounded",
    "heart": "favorite_border favorite_border_rounded favorite_outline",
    "checkCircleSolid": "check_circle check_circle_rounded",
    "checkCircle": "check_circle_outline_rounded check_circle_outline",
    "arrowLeft": "arrow_back arrow_back_ios_new arrow_back_ios arrow_back_rounded",
    "eye": "visibility_outlined visibility",
    "eyeSlash": "visibility_off_outlined visibility_off",
    "exclamationCircle": "error_outline error_outline_rounded error",
    "informationCircle": "info info_outline info_outline_rounded",
    "trash": "delete_outline delete_outline_rounded delete cleaning_services_outlined",
    "chatRound": "chat_bubble_outline_rounded chat_bubble_outline mode_comment_outlined message_outlined",
    "chatRoundFill": "chat_bubble chat_bubble_rounded mode_comment",
    "mapPin": "location_on_outlined pin_drop location_on",
    "mapPinSolid": "location_on_rounded",
    "lockClosed": "lock_outline lock_outlined lock_outline_rounded lock",
    "lockOpen": "lock_open_rounded",
    "key": "lock_reset",
    "photo": "image_outlined image photo_library_rounded add_photo_alternate_outlined panorama_outlined "
             "broken_image broken_image_outlined broken_image_rounded",
    "chevronRight": "chevron_right chevron_right_rounded arrow_forward_ios arrow_forward_ios_rounded",
    "userGroup": "groups_rounded groups_outlined people_outline groups",
    "pencilSquare": "edit edit_outlined edit_rounded edit_note_rounded",
    "film": "movie_creation_outlined video_library_rounded",
    "videoCamera": "videocam videocam_outlined",
    "arrowPath": "refresh refresh_rounded",
    "userPlus": "person_add person_add_outlined person_add_alt_1_rounded group_add_rounded how_to_reg",
    "userMinus": "person_remove_rounded",
    "play": "play_arrow_rounded play_arrow",
    "atSymbol": "alternate_email",
    "volumeHigh": "volume_up",
    "volumeMute": "volume_off volume_off_outlined",
    "calendar": "event calendar_month_rounded calendar_month_outlined calendar_today_outlined "
                "event_available event_busy_outlined",
    "camera": "camera_alt_outlined camera_alt_rounded camera_alt",
    "trophy": "emoji_events_outlined emoji_events military_tech_outlined workspace_premium_outlined "
              "sports sports_rounded sports_outlined sports_soccer stadium_outlined",
    "globeAlt": "language language_outlined public_outlined explore_outlined web_asset_outlined",
    "identification": "badge_outlined assignment_ind_outlined card_membership_outlined contact_mail_outlined",
    "clock": "hourglass_top_rounded hourglass_top hourglass_empty access_time",
    "documentText": "article_outlined description_outlined feed_rounded feed notes_outlined subject "
                    "assignment_outlined",
    "plus": "add",
    "plusCircle": "add_circle_outline add_circle_outline_rounded add_circle",
    "arrowUturnLeft": "reply_rounded reply reply_all_rounded",
    "ellipsisVertical": "more_vert",
    "more": "more_horiz",
    "swatch": "palette_outlined branding_watermark_outlined",
    "starSolid": "star",
    "star": "star_border",
    "sparkles": "stars_outlined stars_rounded diamond_outlined",
    "link": "link link_off",
    "arrowRightOnRectangle": "logout_rounded exit_to_app logout",
    "chevronDown": "keyboard_arrow_down_rounded keyboard_arrow_down arrow_drop_down",
    "send": "send_rounded send send_outlined",
    "exclamationTriangle": "warning_amber_rounded warning_amber",
    "buildingLibrary": "account_balance_outlined account_balance",
    "bookmarkFill": "bookmark",
    "bookmark": "bookmark_border bookmark_border_rounded bookmark_border_outlined",
    "devicePhoneMobile": "phone_android_outlined phone_iphone_outlined phone_android_rounded phone_iphone",
    "envelope": "mail_outline mail_outline_outlined email_outlined mark_email_unread_outlined "
                "mark_email_read_outlined",
    "playCircle": "play_circle_outline play_circle_outline_rounded",
    "flag": "flag_outlined",
    "cloudArrowUp": "cloud_upload_outlined",
    "noSymbol": "block_flipped block_outlined person_off_outlined block",
    "briefcase": "business_center business_center_outlined",
    "documentDuplicate": "copy_rounded copy copy_outlined",
    "bolt": "bolt_rounded flash_on_rounded",
    "chartBar": "bar_chart_rounded bar_chart analytics_outlined table_chart_outlined",
    "questionMarkCircle": "help_outline help_outline_rounded",
    "arrowRight": "arrow_forward arrow_forward_rounded",
    "phone": "phone_outlined",
    "megaphone": "campaign campaign_outlined",
    "scale": "gavel_outlined",
    "bell": "notifications_none notifications_outlined",
    "bellFill": "notifications",
    "wifi": "wifi_rounded",
    "signalSlash": "wifi_off_rounded",
    "chatBubbleLeftRight": "support_agent_outlined",
    "arrowTopRightOnSquare": "open_in_new",
    "buildingOffice": "business business_outlined corporate_fare domain_outlined",
    "buildingStorefront": "store storefront_outlined",
    "squares2X2": "grid_view_rounded grid_on_outlined category",
    "arrowDownTray": "download_rounded",
    "documentArrowDown": "picture_as_pdf picture_as_pdf_outlined document_scanner",
    "currencyRupee": "currency_rupee_rounded",
    "magnifyingGlass": "person_search_outlined search_off_rounded",
    "funnel": "filter_list_outlined filter_alt_outlined",
    "paperClip": "attach_file",
    "arrowTrendingUp": "timeline timeline_outlined trending_up",
    "newspaper": "auto_stories menu_book_outlined newspaper_outlined",
    "folderOpen": "folder_shared_outlined",
    "cake": "cake_outlined",
    "qrCode": "qr_code_outlined",
    "ticket": "event_seat_rounded",
    "cpuChip": "code_outlined laptop_mac_outlined",
}

CUPERTINO = {
    "home": "house",
    "homeFill": "house_fill",
    "search": "search",
    "plusCircle": "plus_circle",
    "playCircle": "play_circle",
    "playCircleFill": "play_circle_fill",
    "user": "person",
    "userSolid": "person_fill",
    "calendar": "calendar",
    "bell": "bell",
    "chatRound": "chat_bubble",
    "cog6Tooth": "gear",
}


def invert(table):
    out = {}
    for target, sources in table.items():
        for source in sources.split():
            out[source] = target
    return out


material = invert(MATERIAL)
cupertino = invert(CUPERTINO)
IMPORT = "import 'package:atheleos/core/widgets/ath_icons.dart';"

changed = 0
unmapped = {}
for path in LIB.rglob("*.dart"):
    if path.name == "ath_icons.dart":
        continue
    with open(path, encoding="utf-8", newline="") as f:
        src = f.read()
    eol = "\r\n" if "\r\n" in src else "\n"

    def sub_material(m):
        name = m.group(1)
        if name in material:
            return "AthIcons." + material[name]
        unmapped[name] = unmapped.get(name, 0) + 1
        return m.group(0)

    def sub_cupertino(m):
        name = m.group(1)
        if name in cupertino:
            return "AthIcons." + cupertino[name]
        unmapped["cupertino:" + name] = unmapped.get("cupertino:" + name, 0) + 1
        return m.group(0)

    new = re.sub(r"(?<![\w.])Icons\.(\w+)\b", sub_material, src)
    new = re.sub(r"(?<![\w.])CupertinoIcons\.(\w+)\b", sub_cupertino, new)
    if new != src:
        if IMPORT not in new:
            imports = list(re.finditer(r"^import [^\n]+;\r?\n", new, re.M))
            pos = imports[-1].end() if imports else 0
            new = new[:pos] + IMPORT + eol + new[pos:]
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(new)
        changed += 1

print("files changed:", changed)
print("unmapped:", sorted(unmapped.items(), key=lambda kv: -kv[1]))
