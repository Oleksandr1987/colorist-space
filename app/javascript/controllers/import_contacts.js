document.addEventListener("DOMContentLoaded", function () {
    const importButton = document.getElementById("import-contacts");
  
    if (importButton) {
      importButton.addEventListener("click", async () => {
        if (!("contacts" in navigator) || !("select" in navigator.contacts)) {
          alert("Your browser does not support contact import.");
          return;
        }
  
        try {
          const props = ["name", "tel"];
          const contacts = await navigator.contacts.select(props, { multiple: true });
  
          const filteredContacts = contacts.map(contact => ({
            first_name: contact.name ? contact.name.split(" ")[0] : "",
            last_name: contact.name ? contact.name.split(" ")[1] || "" : "",
            phone: contact.tel ? contact.tel[0] : ""
          }));
  
          fetch("/clients/import_contacts", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
            },
            body: JSON.stringify({ contacts: filteredContacts })
          })
          .then(response => response.json())
          .then(data => {
            if (data.success) {
              alert("Contacts imported successfully!");
              location.reload();
            } else {
              alert("Failed to import contacts.");
            }
          });
  
        } catch (error) {
          console.error("Contact import failed", error);
        }
      });
    }
  });
  