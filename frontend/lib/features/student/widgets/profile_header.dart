import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/navigation/logout_button.dart';

class ProfileHeader extends StatelessWidget {

  final String name;
  final String hostelId;
  final File? profileImage;
  final VoidCallback onImageTap;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.hostelId,
    required this.profileImage,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),

      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xff6a6ee3),
            Color(0xff8a57c6),
          ],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),

      child: Row(
        children: [

          /// PROFILE IMAGE
          GestureDetector(
            onTap: onImageTap,

            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white,
              backgroundImage:
              profileImage != null ? FileImage(profileImage!) : null,

              child: profileImage == null
                  ? const Icon(
                Icons.camera_alt,
                color: Colors.indigo,
              )
                  : null,
            ),
          ),

          const SizedBox(width: 15),

          /// STUDENT INFO
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                "Hostel ID: $hostelId",
                style: const TextStyle(
                  color: Colors.white70,
                ),
              )

            ],
          ),

          const Spacer(),

          /// LOGOUT BUTTON
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.white,
            ),
            onPressed: (){
              LogoutService.logout(context);
            },
          )

        ],
      ),
    );
  }
}