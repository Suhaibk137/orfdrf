import 'package:flutter/material.dart';

class AdditionalDetailsPage extends StatelessWidget {
  const AdditionalDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.more_horiz, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Additional Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Additional details content will be displayed here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}