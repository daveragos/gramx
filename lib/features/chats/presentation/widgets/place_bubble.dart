import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/domain/message_place.dart';

/// A location or a venue, inside a bubble.
///
/// **No map.** Drawing one would mean fetching tiles from a provider gramX has
/// no key for and does not talk to — a third-party request from a Telegram
/// client, on every location anybody ever sent. So the card says where the
/// place is, names it when Telegram named it, and hands the reader to whatever
/// maps app they already use. That is a card that works offline and leaks
/// nothing.
class PlaceBubble extends StatelessWidget {
  final MessagePlace place;

  /// The bubble's usable width, so the card matches the bubbles around it.
  final double maxWidth;

  final Color foregroundColor;
  final Color mutedColor;

  /// Opens the place in a maps app. Supplied by the screen, because launching
  /// one leaves the app and a widget must not decide that.
  final VoidCallback? onOpen;

  const PlaceBubble({
    super.key,
    required this.place,
    required this.maxWidth,
    required this.foregroundColor,
    required this.mutedColor,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final title = place.isVenue
        ? place.title!
        : (place.isLiveNow
              ? AppStrings.placeLiveLocation
              : AppStrings.locationLabel);

    // Coordinates are the fallback subtitle, not decoration: without an address
    // they are the only thing that says *which* place this is, and they are
    // what somebody would read out over a phone.
    final subtitle =
        place.address ??
        AppStrings.placeCoordinates(place.latitude, place.longitude);

    return Semantics(
      button: onOpen != null,
      label: '$title, $subtitle',
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
        child: Container(
          width: maxWidth,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: mutedColor.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
          ),
          child: Row(
            children: [
              Icon(
                place.isLiveNow
                    ? Icons.my_location_rounded
                    : Icons.location_on_outlined,
                color: foregroundColor,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body(
                        color: foregroundColor,
                      ).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.timestamp(color: mutedColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (onOpen != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          AppStrings.locationOpenInMaps,
                          style: AppTypography.timestamp(
                            color: foregroundColor,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A shared contact, inside a bubble.
class ContactBubble extends StatelessWidget {
  final MessageContactCard contact;
  final double maxWidth;
  final Color foregroundColor;
  final Color mutedColor;

  /// Opens the person's profile. Null when the contact is not on Telegram,
  /// which is what makes the card inert rather than leading nowhere.
  final VoidCallback? onOpen;

  const ContactBubble({
    super.key,
    required this.contact,
    required this.maxWidth,
    required this.foregroundColor,
    required this.mutedColor,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final phone = contact.formattedPhoneNumber;

    return Semantics(
      button: onOpen != null,
      label: '${AppStrings.contactMessage}: ${contact.displayName}',
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
        child: Container(
          width: maxWidth,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: mutedColor.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
          ),
          child: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                color: foregroundColor,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      contact.displayName,
                      style: AppTypography.body(
                        color: foregroundColor,
                      ).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      // A contact whose number is hidden still has a name, and
                      // saying what kind of card it is beats an empty line.
                      phone ?? AppStrings.contactMessage,
                      style: AppTypography.timestamp(color: mutedColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
