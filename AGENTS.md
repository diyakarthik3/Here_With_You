My app is a  wellness app that intersects mental and physical health for the elderly through interactive games that have physical activity checks. There are two different streams, the admin (who puts in all the personalized pictures and rewards) and the user (the one I've currently designed), which is the elderly who logs on and plays these games. There are different personalized games and rewards customized to each person, and a health tracker so users can see how the games have impacted their mental and physical wellness through tangile trackers. Here is some pictures of my app. We can start with a bottom navigation bar with four tabs: home, health, rewards, and settings. Each tab should show a screen with a center title for now. For color scheme, keep consistent with the screenshot I have attached, neutrals with some bright, uplifting colors. 
 
 ## Rules:
- Never put everything in main.dart. Each screen gets its own file in lib/screens/. Shared widgets go in lib/widgets/. Firebase logic goes in lib/services/.
- File naming: snake_case.dart (e.g. login_screen.dart, auth_service.dart)
Always use StatefulWidget for screens with user interaction
- All UI should use consistent  side padding and rounded corners
- Never hardcode Firebase logic inside screens — put it in a service class and call it from the screen
