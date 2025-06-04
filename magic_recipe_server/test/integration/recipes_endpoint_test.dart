import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

import 'package:magic_recipe_server/recipes/recipes_endpoint.dart';
import 'package:magic_recipe_server/src/generated/recipes/recipe.dart';

/// This is our test file for the RecipesEndpoint.

Future<void> expectException(
    Future<void> Function() function, Matcher matcher) async {
  late var actualException;
  try {
    await function();
  } catch (e) {
    actualException = e;
  }
  expect(actualException, matcher);
}

void main() {
  withServerpod('Given Recipes Endpoint',
      (testUnAuthSessionBuilder, endpoints) {
    // testing if the ingredients are passed correctly to the Gemini API
    test(
        'When calling generateRecipe with ingredients, gemini is called with a prompt'
        ' which includes the ingredients', () async {
      // here we are mocking the authentication info to avoid
      // the need to have a real user logged in, and we are using
      // the AuthenticationOverride class to do that. (creating user id 1)
      final testSessionBuilder = testUnAuthSessionBuilder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(1, {}));

      String capturedPrompt = '';

      generateContent = (_, prompt) {
        capturedPrompt = prompt;
        return Future.value('Mock Recipe');
      };

      // here the test file knows that the generateContent function
      // is mocked and it will not call the actual generateContent function,
      // all because of the @visibleForTesting annotation in the top-level
      // generateContent variable.
      final recipe = await endpoints.recipes
          .generateRecipe(testSessionBuilder, 'chicken, rice, broccoli');
      expect(recipe.text, 'Mock Recipe');
      expect(capturedPrompt, contains('chicken, rice, broccoli'));
    });

    // testing soft deletion of recipes
    test(
        'when calling getRecipes, all recipes that are not deleted are returned',
        () async {
      // create a session - with user id 1
      final testSessionBuilder = testUnAuthSessionBuilder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(1, {}));
      final session = testSessionBuilder.build();

      // drop all recipes
      await Recipe.db.deleteWhere(session, where: (t) => t.id.notEquals(null));

      // create a recipe
      final firstRecipe = Recipe(
          author: 'Gemini-2.0-flash',
          text: 'Mock Recipe 1',
          date: DateTime.now(),
          ingredients: 'chicken, rice, broccoli',
          userId: 1);

      await Recipe.db.insertRow(session, firstRecipe);

      // create a second recipe
      final secondRecipe = Recipe(
          author: 'Gemini-2.0-flash',
          text: 'Mock Recipe 2',
          date: DateTime.now(),
          ingredients: 'chicken, rice, broccoli',
          userId: 1);
      await Recipe.db.insertRow(session, secondRecipe);

      // get all recipes
      final recipes = await endpoints.recipes.getRecipes(testSessionBuilder);

      // check that the recipes are returned
      expect(recipes.length, 2);

      // get the first recipe to get its id
      final recipeToDelete = await Recipe.db.findFirstRow(
        session,
        where: (t) => t.text.equals('Mock Recipe 1'),
      );

      // delete the first recipe
      await endpoints.recipes
          .deleteRecipe(testSessionBuilder, recipeToDelete!.id!);

      // get all recipes
      final recipes2 = await endpoints.recipes.getRecipes(testSessionBuilder);
      // check that the recipes are returned
      expect(recipes2.length, 1);
      expect(recipes2[0].text, 'Mock Recipe 2');
    });

    test('when deleting a recipe users can only delete their own recipes',
        () async {
      final sessionBuilder = testUnAuthSessionBuilder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(1, {}));
      final session = sessionBuilder.build();

      await Recipe.db.insert(session, [
        Recipe(
            author: 'Gemini',
            text: 'Mock Recipe 1',
            date: DateTime.now(),
            userId: 1,
            ingredients: 'chicken, rice, broccoli'),
        Recipe(
            author: 'Gemini',
            text: 'Mock Recipe 2',
            date: DateTime.now(),
            userId: 1,
            ingredients: 'chicken, rice, broccoli'),
        Recipe(
            author: 'Gemini',
            text: 'Mock Recipe 3',
            date: DateTime.now(),
            userId: 2,
            ingredients: 'chicken, rice, broccoli'),
      ]);

      // get the first recipe to get its id
      final recipeToDelete = await Recipe.db.findFirstRow(
        session,
        where: (t) => t.text.equals('Mock Recipe 1'),
      );

      // delete the first recipe
      await endpoints.recipes.deleteRecipe(sessionBuilder, recipeToDelete!.id!);

      // try to delete a recipe that is not yours

      final recipeYouShouldntDelete = await Recipe.db.findFirstRow(
        session,
        where: (t) => t.text.equals('Mock Recipe 3'),
      );

      await expectException(
        () => endpoints.recipes
            .deleteRecipe(sessionBuilder, recipeYouShouldntDelete!.id!),
        isA<Exception>(),
      );
    });

    // verify unauthenticated users cannot interact with the API
    test('when delete recipe with unauthenticated user, an exception is thrown',
        () async {
      await expectException(
        () => endpoints.recipes.deleteRecipe(testUnAuthSessionBuilder, 1),
        isA<ServerpodUnauthenticatedException>(),
      );
    });

    test(
        'when trying to generate a recipe as an unauthenticated user an exception is thrown',
        () async {
      await expectException(
        () => endpoints.recipes.generateRecipe(
            testUnAuthSessionBuilder, 'chicken, rice, broccoli'),
        isA<ServerpodUnauthenticatedException>(),
      );
    });

    test(
        'when trying to get recipes as an unauthenticated user an exception is thrown',
        () async {
      await expectException(
        () => endpoints.recipes.getRecipes(testUnAuthSessionBuilder),
        isA<ServerpodUnauthenticatedException>(),
      );
    });
  });
}
