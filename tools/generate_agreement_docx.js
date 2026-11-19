const fs = require('fs');
const path = require('path');
const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  Table,
  TableRow,
  TableCell,
  WidthType,
  BorderStyle,
  AlignmentType,
  ShadingType
} = require('docx');

function createAgreementDocx() {
  const primaryColor = "1E3A8A"; // Navy Blue
  const darkTextColor = "0F172A";
  const mutedTextColor = "475569";
  const lightBg = "F8FAFC";
  const highlightBg = "EFF6FF";
  const borderGrey = "CBD5E1";

  const lightBorder = {
    top: { style: BorderStyle.SINGLE, size: 1, color: borderGrey },
    bottom: { style: BorderStyle.SINGLE, size: 1, color: borderGrey },
    left: { style: BorderStyle.SINGLE, size: 1, color: borderGrey },
    right: { style: BorderStyle.SINGLE, size: 1, color: borderGrey }
  };

  const noBorder = {
    top: { style: BorderStyle.NONE },
    bottom: { style: BorderStyle.NONE },
    left: { style: BorderStyle.NONE },
    right: { style: BorderStyle.NONE }
  };

  const sectionHeader = (text, number) => {
    return new Paragraph({
      spacing: { before: 100, after: 40 },
      children: [
        new TextRun({
          text: `${number}. ${text.toUpperCase()}`,
          bold: true,
          size: 19, // 9.5pt
          color: primaryColor,
          font: "Arial"
        })
      ]
    });
  };

  const bulletItem = (boldPrefix, text) => {
    return new Paragraph({
      spacing: { before: 20, after: 20 },
      indent: { left: 240 },
      children: [
        new TextRun({
          text: "• ",
          bold: true,
          color: primaryColor,
          size: 18,
          font: "Arial"
        }),
        new TextRun({
          text: boldPrefix + ": ",
          bold: true,
          color: darkTextColor,
          size: 18, // 9pt
          font: "Arial"
        }),
        new TextRun({
          text: text,
          color: darkTextColor,
          size: 18, // 9pt
          font: "Arial"
        })
      ]
    });
  };

  const doc = new Document({
    sections: [
      {
        properties: {
          page: {
            margin: {
              top: 576,    // 0.4 in
              bottom: 576, // 0.4 in
              left: 720,   // 0.5 in
              right: 720   // 0.5 in
            }
          }
        },
        children: [
          // Header Table (Title & Metadata)
          new Table({
            width: { size: 100, type: WidthType.PERCENTAGE },
            borders: {
              top: { style: BorderStyle.NONE },
              left: { style: BorderStyle.NONE },
              right: { style: BorderStyle.NONE },
              bottom: { style: BorderStyle.SINGLE, size: 12, color: primaryColor }
            },
            rows: [
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 65, type: WidthType.PERCENTAGE },
                    borders: noBorder,
                    children: [
                      new Paragraph({
                        spacing: { after: 20 },
                        children: [
                          new TextRun({
                            text: "SOFTWARE LICENSE & SERVICE AGREEMENT",
                            bold: true,
                            size: 24, // 12pt
                            color: primaryColor,
                            font: "Arial"
                          })
                        ]
                      }),
                      new Paragraph({
                        children: [
                          new TextRun({
                            text: "Qodex CafeFlow v1.0.0 — Restaurant POS & Cafe Management System",
                            size: 17, // 8.5pt
                            color: mutedTextColor,
                            font: "Arial",
                            italics: true
                          })
                        ]
                      })
                    ]
                  }),
                  new TableCell({
                    width: { size: 35, type: WidthType.PERCENTAGE },
                    borders: noBorder,
                    children: [
                      new Paragraph({
                        alignment: AlignmentType.RIGHT,
                        spacing: { after: 15 },
                        children: [
                          new TextRun({ text: "Ref: ", bold: true, size: 17, color: mutedTextColor, font: "Arial" }),
                          new TextRun({ text: "CF-AGR-2026-001", bold: true, size: 17, color: darkTextColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        alignment: AlignmentType.RIGHT,
                        children: [
                          new TextRun({ text: "Date: ", bold: true, size: 17, color: mutedTextColor, font: "Arial" }),
                          new TextRun({ text: "September 15, 2026", size: 17, color: darkTextColor, font: "Arial" })
                        ]
                      })
                    ]
                  })
                ]
              })
            ]
          }),

          // Section 1: Contracting Parties
          sectionHeader("Parties Involved", "1"),
          new Table({
            width: { size: 100, type: WidthType.PERCENTAGE },
            borders: lightBorder,
            rows: [
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 50, type: WidthType.PERCENTAGE },
                    shading: { type: ShadingType.CLEAR, fill: lightBg },
                    borders: lightBorder,
                    children: [
                      new Paragraph({
                        children: [
                          new TextRun({ text: "SERVICE PROVIDER / DEVELOPER:", bold: true, size: 16, color: primaryColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        spacing: { before: 20 },
                        children: [
                          new TextRun({ text: "Qodex Software", bold: true, size: 18, color: darkTextColor, font: "Arial" }),
                          new TextRun({ text: " (Software & POS Solutions)", size: 16, color: mutedTextColor, font: "Arial" })
                        ]
                      })
                    ]
                  }),
                  new TableCell({
                    width: { size: 50, type: WidthType.PERCENTAGE },
                    shading: { type: ShadingType.CLEAR, fill: lightBg },
                    borders: lightBorder,
                    children: [
                      new Paragraph({
                        children: [
                          new TextRun({ text: "CLIENT / LICENSEE:", bold: true, size: 16, color: primaryColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        spacing: { before: 20 },
                        children: [
                          new TextRun({ text: "Cafe Indus", bold: true, size: 18, color: darkTextColor, font: "Arial" }),
                          new TextRun({ text: " (Authorized Cafe Management)", size: 16, color: mutedTextColor, font: "Arial" })
                        ]
                      })
                    ]
                  })
                ]
              })
            ]
          }),

          // Section 2: Software Scope & Details
          sectionHeader("Software Scope & Core Functional Modules", "2"),
          new Paragraph({
            spacing: { before: 20, after: 30 },
            children: [
              new TextRun({
                text: "The Provider licenses and delivers Qodex CafeFlow (v1.0.0), encompassing the following operational modules:",
                size: 17,
                color: mutedTextColor,
                font: "Arial"
              })
            ]
          }),
          bulletItem("POS Billing & Invoicing", "Fast counter order entry, split bill options, customizable receipts & thermal printer integration."),
          bulletItem("Floor & Table Management", "Dine-in floor layouts, real-time table status tracking, and waiter staff assignment."),
          bulletItem("Menu & Categories", "Comprehensive item catalog management, category organization, prices, and variants."),
          bulletItem("Recipe & Inventory Tracking", "Ingredient linking to dishes with automated deduction from stock upon sale."),
          bulletItem("Purchases & Raw Materials", "Vendor meat and grocery purchasing logs with unit cost and weight tracking."),
          bulletItem("Expenses & Profit/Loss Reports", "Daily expense tracker, daily/monthly revenue metrics, top sellers, and margin analytics."),
          bulletItem("Invoice History & Dashboard", "Complete sales logs, bill reprints, and live executive dashboard charts."),

          // Section 3: Local Database Architecture
          sectionHeader("Local Database Architecture & Complete Data Autonomy", "3"),
          new Table({
            width: { size: 100, type: WidthType.PERCENTAGE },
            borders: lightBorder,
            rows: [
              new TableRow({
                children: [
                  new TableCell({
                    shading: { type: ShadingType.CLEAR, fill: highlightBg },
                    borders: lightBorder,
                    children: [
                      new Paragraph({
                        spacing: { after: 30 },
                        children: [
                          new TextRun({ text: "Dedicated Local SQLite Database (cafe_flow.db):", bold: true, size: 18, color: primaryColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        spacing: { before: 15, after: 15 },
                        children: [
                          new TextRun({ text: "✔ 100% Offline Capability: ", bold: true, size: 17, color: "065F46", font: "Arial" }),
                          new TextRun({ text: "Operates with zero internet dependence. Counter billing, kitchen orders, and invoicing continue uninterrupted during internet outages.", size: 17, color: darkTextColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        spacing: { before: 15, after: 15 },
                        children: [
                          new TextRun({ text: "✔ Total Privacy & Data Ownership: ", bold: true, size: 17, color: "065F46", font: "Arial" }),
                          new TextRun({ text: "All transaction logs, pricing, supplier rates, and customer data remain 100% locally on the client's PC. No unauthorized cloud telemetry.", size: 17, color: darkTextColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        spacing: { before: 15, after: 0 },
                        children: [
                          new TextRun({ text: "✔ Zero Recurring Cloud Costs: ", bold: true, size: 17, color: "065F46", font: "Arial" }),
                          new TextRun({ text: "No recurring monthly/annual cloud server or database hosting subscriptions required for daily operations.", size: 17, color: darkTextColor, font: "Arial" })
                        ]
                      })
                    ]
                  })
                ]
              })
            ]
          }),

          // Section 4: Cost & Commercial Terms
          sectionHeader("Financial Terms & System Cost", "4"),
          new Table({
            width: { size: 100, type: WidthType.PERCENTAGE },
            borders: lightBorder,
            rows: [
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 70, type: WidthType.PERCENTAGE },
                    shading: { type: ShadingType.CLEAR, fill: lightBg },
                    borders: lightBorder,
                    children: [
                      new Paragraph({
                        children: [
                          new TextRun({ text: "Agreed Total System Investment (v1.0.0 Delivery):", bold: true, size: 18, color: darkTextColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        spacing: { before: 20 },
                        children: [
                          new TextRun({ text: "Includes complete software installation, local database setup, testing & staff orientation.", size: 16, color: mutedTextColor, font: "Arial" })
                        ]
                      })
                    ]
                  }),
                  new TableCell({
                    width: { size: 30, type: WidthType.PERCENTAGE },
                    shading: { type: ShadingType.CLEAR, fill: lightBg },
                    borders: lightBorder,
                    children: [
                      new Paragraph({
                        alignment: AlignmentType.RIGHT,
                        children: [
                          new TextRun({ text: "PKR 25,000/-", bold: true, size: 24, color: primaryColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        alignment: AlignmentType.RIGHT,
                        children: [
                          new TextRun({ text: "(One-time Payment)", size: 15, color: mutedTextColor, font: "Arial" })
                        ]
                      })
                    ]
                  })
                ]
              })
            ]
          }),

          // Section 5: Future Changes
          sectionHeader("Future Changes & Additional Modifications Policy", "5"),
          new Table({
            width: { size: 100, type: WidthType.PERCENTAGE },
            borders: lightBorder,
            rows: [
              new TableRow({
                children: [
                  new TableCell({
                    shading: { type: ShadingType.CLEAR, fill: "FEF3C7" }, // Warm Amber warning/notice
                    borders: lightBorder,
                    children: [
                      new Paragraph({
                        children: [
                          new TextRun({ text: "Scope Boundary & Separate Billing Clause: ", bold: true, size: 17, color: "92400E", font: "Arial" }),
                          new TextRun({
                            text: "The agreed cost of PKR 25,000 covers strictly the defined v1.0.0 features and deliverables. Any subsequent changes, feature additions, layout modifications, new hardware integrations, or workflow revisions requested by the Client will be charged separately under mutually agreed quotes based on scope and effort.",
                            size: 17,
                            color: "78350F",
                            font: "Arial"
                          })
                        ]
                      })
                    ]
                  })
                ]
              })
            ]
          }),

          // Section 6: Acceptance & Signatures
          sectionHeader("Acceptance & Authorization", "6"),
          new Table({
            width: { size: 100, type: WidthType.PERCENTAGE },
            borders: lightBorder,
            rows: [
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 50, type: WidthType.PERCENTAGE },
                    borders: lightBorder,
                    children: [
                      new Paragraph({
                        children: [
                          new TextRun({ text: "FOR: Qodex Software (Provider)", bold: true, size: 17, color: primaryColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        spacing: { before: 200, after: 20 },
                        children: [
                          new TextRun({ text: "Signature: _________________________________", size: 17, color: darkTextColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        children: [
                          new TextRun({ text: "Name: Authorized Representative\nTitle: Solutions Architect", size: 15, color: mutedTextColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        spacing: { before: 30 },
                        children: [
                          new TextRun({ text: "Date: ______ / ______ / 2026", size: 16, color: darkTextColor, font: "Arial" })
                        ]
                      })
                    ]
                  }),
                  new TableCell({
                    width: { size: 50, type: WidthType.PERCENTAGE },
                    borders: lightBorder,
                    children: [
                      new Paragraph({
                        children: [
                          new TextRun({ text: "FOR: Cafe Indus (Client)", bold: true, size: 17, color: primaryColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        spacing: { before: 200, after: 20 },
                        children: [
                          new TextRun({ text: "Signature: _________________________________", size: 17, color: darkTextColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        children: [
                          new TextRun({ text: "Name: Authorized Signatory\nTitle: Owner / General Manager", size: 15, color: mutedTextColor, font: "Arial" })
                        ]
                      }),
                      new Paragraph({
                        spacing: { before: 30 },
                        children: [
                          new TextRun({ text: "Date: ______ / ______ / 2026", size: 16, color: darkTextColor, font: "Arial" })
                        ]
                      })
                    ]
                  })
                ]
              })
            ]
          }),

          // Footer Notice
          new Paragraph({
            spacing: { before: 60 },
            alignment: AlignmentType.CENTER,
            children: [
              new TextRun({
                text: "Qodex CafeFlow • Single Page Commercial Agreement • Confidential & Legally Binding",
                size: 14, // 7pt
                color: mutedTextColor,
                font: "Arial",
                italics: true
              })
            ]
          })
        ]
      }
    ]
  });

  const outputPath = path.resolve(__dirname, '..', 'SOFTWARE_AGREEMENT.docx');
  Packer.toBuffer(doc).then((buffer) => {
    fs.writeFileSync(outputPath, buffer);
    console.log("Successfully generated: " + outputPath);
  }).catch((err) => {
    console.error("Error generating docx:", err);
    process.exit(1);
  });
}

createAgreementDocx();
