import 'package:get/get.dart';
import 'package:t_rider_services_app/data/models/language_model.dart';
import 'package:t_rider_services_app/data/repositories/language_repository.dart';
import 'package:t_rider_services_app/utils/api_error_message.dart';
import 'package:t_rider_services_app/views/splash/auth_screens/registration_screen.dart';

class LanguageController extends GetxController {
  LanguageController({LanguageRepository? repository})
    : _repository = repository ?? LanguageRepository();

  final LanguageRepository _repository;

  final Rxn<LanguageModel> selectedLanguage = Rxn<LanguageModel>();
  final RxString searchQuery = ''.obs;
  final RxList<LanguageModel> allLanguages = <LanguageModel>[].obs;
  final RxList<LanguageModel> filteredLanguages = <LanguageModel>[].obs;

  final RxBool isLoading = true.obs;
  final Rxn<String> errorMessage = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    fetchLanguages();
  }

  Future<void> fetchLanguages() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _repository.getLanguages();
      allLanguages.value = list;
      filteredLanguages.value = List.from(list);
    } catch (e) {
      errorMessage.value = apiErrorMessage(
        e,
        fallback: 'could_not_load_languages'.tr,
      );
      allLanguages.value = [];
      filteredLanguages.value = [];
    } finally {
      isLoading.value = false;
    }
  }

  void onSearchChanged(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      filteredLanguages.value = List.from(allLanguages);
    } else {
      filteredLanguages.value = allLanguages
          .where(
            (l) =>
                l.name.toLowerCase().contains(query.toLowerCase()) ||
                l.code.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }
  }

  void selectLanguage(LanguageModel language) {
    selectedLanguage.value = language;
  }

  void continueAction() {
    if (selectedLanguage.value != null) {
      Get.offAll(() => const RegistrationScreen());
    }
  }
}
