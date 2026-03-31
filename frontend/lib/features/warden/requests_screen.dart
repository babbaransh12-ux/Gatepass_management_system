import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

import '../../core/navigation/logout_button.dart';
import '../../data/models/leave_request_model.dart';
import '../../data/repositories/warden_repository.dart';

import 'package:e_gatepass/features//warden/widget/leave_request_card.dart';
import 'package:e_gatepass/features//warden/widget/swipe_overlay.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {

  final CardSwiperController controller = CardSwiperController();
  final WardenRepository repository = WardenRepository();

  List<LeaveRequestModel> requests = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  /// Load requests from backend
  Future<void> loadRequests() async {

    try {

      final data = await repository.fetchPendingRequests();

      setState(() {
        requests = data;
        isLoading = false;
      });

    } catch (e) {

      setState(() {
        isLoading = false;
      });

      debugPrint("Error loading requests: $e");
    }
  }

  /// Approve request
  Future<void> approveRequest(int index) async {

    final requestId = requests[index].requestId;

    await repository.approveRequest(requestId);

    setState(() {
      requests.removeAt(index);
    });
  }

  /// Reject request
  Future<void> rejectRequest(int index) async {

    final requestId = requests[index].requestId;

    await repository.rejectRequest(requestId);

    setState(() {
      requests.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Leave Requests"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: (){
              LogoutService.logout(context);
            },
          )
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
          ? const Center(child: Text("No pending requests"))
          : Padding(
        padding: const EdgeInsets.all(20),

        child: CardSwiper(

          controller: controller,

          cardsCount: requests.length,

          numberOfCardsDisplayed:
          requests.length >= 2 ? 2 : 1,

          cardBuilder: (context, index, px, py) {

            return Stack(
              children: [

                LeaveRequestCard(
                  request: requests[index],
                ),

                if(px > 0.3)
                  const SwipeOverlay(isRight: true),

                if(px < -0.3)
                  const SwipeOverlay(isRight: false),

              ],
            );
          },

          onSwipe: (previousIndex, currentIndex, direction) {

            if(direction == CardSwiperDirection.right){

              approveRequest(previousIndex);
              debugPrint("Approved ${requests[previousIndex].requestId}");

            }

            if(direction == CardSwiperDirection.left){

              rejectRequest(previousIndex);
              debugPrint("Rejected ${requests[previousIndex].requestId}");

            }

            return true;
          },

        ),
      ),

      /// Manual approve / reject buttons
      floatingActionButton: requests.isEmpty
          ? null
          : Row(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          FloatingActionButton(
            heroTag: "reject",
            backgroundColor: Colors.white,
            child: const Icon(Icons.close, color: Colors.red),
            onPressed: (){
              controller.swipe(CardSwiperDirection.left);
            },
          ),

          const SizedBox(width: 40),

          FloatingActionButton(
            heroTag: "approve",
            backgroundColor: Colors.white,
            child: const Icon(Icons.check, color: Colors.green),
            onPressed: (){
              controller.swipe(CardSwiperDirection.right);
            },
          ),

        ],
      ),

      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerFloat,

    );
  }
}