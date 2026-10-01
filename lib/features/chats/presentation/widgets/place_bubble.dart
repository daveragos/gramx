import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/domain/message_place.dart';

/// A location or venue inside a bubble. Shows no map, since that would mean
/// requesting tiles from a third-party provider; tapping opens a maps app.
class PlaceBubble extends StatelessWidget {
  final MessagePlace place;

  /// The bubble's usable width.
  final double maxWidth;

  final Color foregroundColor;
  final Color mutedColor;

  /// Opens the place in a maps app.
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

    // Coordinates when there is no address.
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

  /// Opens the contact's profile. Null when they aren't on Telegram.
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
                      // A generic label when the number is hidden.
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
